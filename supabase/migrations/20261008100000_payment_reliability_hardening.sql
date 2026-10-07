-- Payment reliability and security hardening
-- 2026-10-08

ALTER TABLE public.payments
  ADD COLUMN IF NOT EXISTS paid_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS payment_reference VARCHAR(100);

CREATE INDEX IF NOT EXISTS idx_payments_room_id
  ON public.payments (room_id);

CREATE INDEX IF NOT EXISTS idx_device_tokens_profile_id
  ON public.device_tokens (profile_id);

CREATE UNIQUE INDEX IF NOT EXISTS uq_payment_transactions_active_payment
  ON public.payment_transactions (payment_id)
  WHERE status IN ('created', 'pending', 'waiting_confirmation');

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'chk_payment_transactions_status'
  ) THEN
    ALTER TABLE public.payment_transactions
      ADD CONSTRAINT chk_payment_transactions_status
      CHECK (status IN (
        'created', 'pending', 'success', 'failed', 'expired', 'cancelled',
        'waiting_confirmation', 'rejected'
      ));
  END IF;
END $$;

CREATE OR REPLACE FUNCTION public.generate_recurring_invoices()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_tenant RECORD;
    v_period VARCHAR(20);
    v_start_date DATE;
    v_end_date DATE;
    v_due_date DATE;
    v_count INTEGER := 0;
BEGIN
    FOR v_tenant IN
        SELECT t.id AS tenant_id, t.property_id, t.room_id, t.rent_price, t.end_date, t.profile_id
        FROM public.tenants t
        WHERE t.status = 'active' AND t.end_date <= CURRENT_DATE
    LOOP
        v_start_date := (v_tenant.end_date + INTERVAL '1 day')::date;
        v_end_date := (v_start_date + INTERVAL '1 month' - INTERVAL '1 day')::date;
        v_period := pg_catalog.to_char(v_start_date, 'YYYY-MM');
        v_due_date := v_start_date;

        INSERT INTO public.payments (
            property_id, tenant_id, room_id, invoice_number, billing_period,
            period_start, period_end, due_date, amount_due, amount_paid, status, is_renewal
        )
        VALUES (
            v_tenant.property_id, v_tenant.tenant_id, v_tenant.room_id,
            'INV/' || pg_catalog.to_char(v_start_date, 'YYYYMM') || '/' ||
              pg_catalog.substring(v_tenant.tenant_id::text from 1 for 6),
            v_period, v_start_date, v_end_date, v_due_date,
            COALESCE(v_tenant.rent_price, 0), 0, 'unpaid', true
        )
        ON CONFLICT (tenant_id, billing_period) DO NOTHING;

        IF FOUND THEN
            v_count := v_count + 1;
            IF v_tenant.profile_id IS NOT NULL THEN
                INSERT INTO public.notifications (profile_id, title, message, type, data)
                VALUES (
                    v_tenant.profile_id,
                    'Tagihan Sewa Baru Tersedia',
                    'Tagihan sewa kos periode ' || v_period || ' telah terbit. Silakan lakukan pembayaran.',
                    'invoice_created',
                    pg_catalog.jsonb_build_object('billing_period', v_period, 'amount_due', v_tenant.rent_price)
                );
            END IF;
        END IF;
    END LOOP;
    RETURN v_count;
END;
$$;

CREATE OR REPLACE FUNCTION public.apply_rental_renewal(p_payment_id UUID)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_payment RECORD;
    v_tenant RECORD;
    v_old_end_date DATE;
    v_new_end_date DATE;
BEGIN
    UPDATE public.payments
    SET renewal_applied_at = NOW()
    WHERE id = p_payment_id
      AND status = 'paid'
      AND is_renewal = true
      AND renewal_applied_at IS NULL
    RETURNING tenant_id INTO v_payment;

    IF NOT FOUND THEN RETURN false; END IF;

    SELECT id, end_date INTO v_tenant
    FROM public.tenants
    WHERE id = v_payment.tenant_id AND status = 'active'
    FOR UPDATE;

    IF NOT FOUND THEN RETURN false; END IF;

    v_old_end_date := v_tenant.end_date;
    v_new_end_date := (v_old_end_date + INTERVAL '1 month')::date;

    UPDATE public.tenants
    SET end_date = v_new_end_date, updated_at = NOW()
    WHERE id = v_tenant.id;

    INSERT INTO public.rental_renewals (
      payment_id, tenant_id, previous_end_date, new_end_date
    )
    VALUES (p_payment_id, v_tenant.id, v_old_end_date, v_new_end_date);

    RETURN true;
END;
$$;

CREATE OR REPLACE FUNCTION public.update_overdue_invoices()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_count INTEGER := 0;
BEGIN
    UPDATE public.payments
    SET status = 'overdue', updated_at = NOW()
    WHERE status IN ('unpaid', 'partial')
      AND due_date IS NOT NULL
      AND CURRENT_DATE > (due_date + grace_period_days * INTERVAL '1 day')::date;

    GET DIAGNOSTICS v_count = ROW_COUNT;
    RETURN v_count;
END;
$$;

CREATE OR REPLACE FUNCTION public.update_payment_transactions_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.generate_recurring_invoices() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.apply_rental_renewal(UUID) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.update_overdue_invoices() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.update_payment_transactions_updated_at() FROM PUBLIC, anon, authenticated;

-- Existing RLS policies: cache auth.uid() once per statement.
DROP POLICY IF EXISTS payment_tx_tenant_select ON public.payment_transactions;
CREATE POLICY payment_tx_tenant_select ON public.payment_transactions
FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.tenants t
    WHERE t.id = payment_transactions.tenant_id
      AND t.profile_id = (SELECT auth.uid())
  )
);

DROP POLICY IF EXISTS payment_tx_owner_select ON public.payment_transactions;
CREATE POLICY payment_tx_owner_select ON public.payment_transactions
FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.payments p
    JOIN public.properties prop ON prop.id = p.property_id
    WHERE p.id = payment_transactions.payment_id
      AND prop.owner_id = (SELECT auth.uid())
  )
);

DROP POLICY IF EXISTS renewals_tenant_select ON public.rental_renewals;
CREATE POLICY renewals_tenant_select ON public.rental_renewals
FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.tenants t
    WHERE t.id = rental_renewals.tenant_id
      AND t.profile_id = (SELECT auth.uid())
  )
);

DROP POLICY IF EXISTS renewals_owner_select ON public.rental_renewals;
CREATE POLICY renewals_owner_select ON public.rental_renewals
FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.payments p
    JOIN public.properties prop ON prop.id = p.property_id
    WHERE p.id = rental_renewals.payment_id
      AND prop.owner_id = (SELECT auth.uid())
  )
);

DROP POLICY IF EXISTS notif_select_own ON public.notifications;
CREATE POLICY notif_select_own ON public.notifications
FOR SELECT TO authenticated
USING (profile_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS notif_update_own ON public.notifications;
CREATE POLICY notif_update_own ON public.notifications
FOR UPDATE TO authenticated
USING (profile_id = (SELECT auth.uid()))
WITH CHECK (profile_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS device_tokens_own ON public.device_tokens;
CREATE POLICY device_tokens_own ON public.device_tokens
FOR ALL TO authenticated
USING (profile_id = (SELECT auth.uid()))
WITH CHECK (profile_id = (SELECT auth.uid()));
