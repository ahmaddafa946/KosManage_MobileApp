-- ============================================================================
-- MIGRATION: Payment & Automatic Billing System
-- Version: 1.0.0
-- Date: 2026-10-08
-- Description: Extends payments table, adds transaction tracking, webhook
--              audit log, rental renewal audit trail, notifications, and
--              device tokens. Includes RLS, stored procedures, and pg_cron.
-- ============================================================================

-- ============================================================================
-- 1. EXTEND EXISTING payments TABLE (Zero Breaking Changes)
-- ============================================================================
-- Add new columns that do NOT break existing queries.
-- All new columns are nullable or have defaults.

ALTER TABLE public.payments
  ADD COLUMN IF NOT EXISTS invoice_number VARCHAR(64),
  ADD COLUMN IF NOT EXISTS period_start DATE,
  ADD COLUMN IF NOT EXISTS period_end DATE,
  ADD COLUMN IF NOT EXISTS grace_period_days INTEGER NOT NULL DEFAULT 3,
  ADD COLUMN IF NOT EXISTS is_renewal BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS renewal_applied_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS paid_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS payment_reference VARCHAR(100),
  ADD COLUMN IF NOT EXISTS metadata JSONB NOT NULL DEFAULT '{}'::jsonb;

-- Add unique constraint for idempotent billing (tenant + period = unique invoice)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'uq_payments_tenant_billing_period'
  ) THEN
    ALTER TABLE public.payments
      ADD CONSTRAINT uq_payments_tenant_billing_period
      UNIQUE (tenant_id, billing_period);
  END IF;
END
$$;

-- Add check constraints for financial integrity
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'chk_payments_amount_due_positive'
  ) THEN
    ALTER TABLE public.payments ADD CONSTRAINT chk_payments_amount_due_positive CHECK (amount_due >= 0);
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'chk_payments_amount_paid_positive'
  ) THEN
    ALTER TABLE public.payments ADD CONSTRAINT chk_payments_amount_paid_positive CHECK (amount_paid >= 0);
  END IF;
END
$$;

-- Performance indexes
CREATE INDEX IF NOT EXISTS idx_payments_property_due ON public.payments (property_id, due_date DESC);
CREATE INDEX IF NOT EXISTS idx_payments_tenant_status ON public.payments (tenant_id, status);

-- ============================================================================
-- 2. CREATE payment_transactions TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.payment_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  payment_id UUID NOT NULL REFERENCES public.payments(id) ON DELETE CASCADE,
  tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  order_id VARCHAR(100) NOT NULL,
  payment_method VARCHAR(30) NOT NULL,
  payment_provider VARCHAR(30) NOT NULL DEFAULT 'midtrans',
  gross_amount NUMERIC(12,2) NOT NULL,
  status VARCHAR(30) NOT NULL DEFAULT 'created',
  va_number VARCHAR(50),
  bank VARCHAR(20),
  qr_string TEXT,
  qr_url TEXT,
  gateway_reference VARCHAR(100),
  expires_at TIMESTAMPTZ,
  paid_at TIMESTAMPTZ,
  payload_response JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT uq_payment_transactions_order_id UNIQUE (order_id)
);

CREATE INDEX IF NOT EXISTS idx_payment_tx_payment ON public.payment_transactions (payment_id);
CREATE INDEX IF NOT EXISTS idx_payment_tx_tenant ON public.payment_transactions (tenant_id);
CREATE INDEX IF NOT EXISTS idx_payment_tx_order ON public.payment_transactions (order_id);
CREATE INDEX IF NOT EXISTS idx_payment_tx_status ON public.payment_transactions (status);

-- ============================================================================
-- 3. CREATE payment_webhook_events TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.payment_webhook_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id VARCHAR(100) NOT NULL,
  event_type VARCHAR(50) NOT NULL,
  transaction_status VARCHAR(50) NOT NULL,
  signature_key VARCHAR(255) NOT NULL,
  raw_payload JSONB NOT NULL,
  processed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT uq_webhook_event_order_status UNIQUE (order_id, transaction_status)
);

-- ============================================================================
-- 4. CREATE rental_renewals TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.rental_renewals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  payment_id UUID NOT NULL REFERENCES public.payments(id),
  tenant_id UUID NOT NULL REFERENCES public.tenants(id),
  previous_end_date DATE NOT NULL,
  new_end_date DATE NOT NULL,
  renewed_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_rental_renewals_tenant ON public.rental_renewals (tenant_id);
CREATE INDEX IF NOT EXISTS idx_rental_renewals_payment ON public.rental_renewals (payment_id);

-- ============================================================================
-- 5. CREATE notifications TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  title VARCHAR(200) NOT NULL,
  message TEXT NOT NULL,
  type VARCHAR(50) NOT NULL,
  data JSONB NOT NULL DEFAULT '{}'::jsonb,
  is_read BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notifications_profile ON public.notifications (profile_id, is_read, created_at DESC);

-- ============================================================================
-- 6. CREATE device_tokens TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.device_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  token TEXT NOT NULL,
  platform VARCHAR(10) NOT NULL DEFAULT 'android',
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT uq_device_tokens_token UNIQUE (token)
);

-- ============================================================================
-- 7. ENABLE ROW LEVEL SECURITY ON ALL NEW TABLES
-- ============================================================================
ALTER TABLE public.payment_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_webhook_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rental_renewals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.device_tokens ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- 8. RLS POLICIES: payment_transactions
-- ============================================================================
-- Tenant can read own transactions
CREATE POLICY payment_tx_tenant_select ON public.payment_transactions
FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.tenants t
    WHERE t.id = payment_transactions.tenant_id
      AND t.profile_id = auth.uid()
  )
);

-- Owner can read transactions on their property
CREATE POLICY payment_tx_owner_select ON public.payment_transactions
FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.payments p
    JOIN public.properties prop ON prop.id = p.property_id
    WHERE p.id = payment_transactions.payment_id
      AND prop.owner_id = auth.uid()
  )
);

-- No INSERT/UPDATE/DELETE policies for authenticated users.
-- All mutations happen via Edge Functions using service_role.

-- ============================================================================
-- 9. RLS POLICIES: payment_webhook_events
-- ============================================================================
-- Only service_role can access webhook events (audit log)
CREATE POLICY webhook_events_service_role_only ON public.payment_webhook_events
FOR ALL TO service_role
USING (true)
WITH CHECK (true);

-- ============================================================================
-- 10. RLS POLICIES: rental_renewals
-- ============================================================================
CREATE POLICY renewals_tenant_select ON public.rental_renewals
FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.tenants t
    WHERE t.id = rental_renewals.tenant_id
      AND t.profile_id = auth.uid()
  )
);

CREATE POLICY renewals_owner_select ON public.rental_renewals
FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.payments p
    JOIN public.properties prop ON prop.id = p.property_id
    WHERE p.id = rental_renewals.payment_id
      AND prop.owner_id = auth.uid()
  )
);

-- ============================================================================
-- 11. RLS POLICIES: notifications
-- ============================================================================
CREATE POLICY notif_select_own ON public.notifications
FOR SELECT TO authenticated
USING (profile_id = auth.uid());

CREATE POLICY notif_update_own ON public.notifications
FOR UPDATE TO authenticated
USING (profile_id = auth.uid())
WITH CHECK (profile_id = auth.uid());

-- ============================================================================
-- 12. RLS POLICIES: device_tokens
-- ============================================================================
CREATE POLICY device_tokens_own ON public.device_tokens
FOR ALL TO authenticated
USING (profile_id = auth.uid())
WITH CHECK (profile_id = auth.uid());

-- ============================================================================
-- 13. STORED PROCEDURE: generate_recurring_invoices()
-- ============================================================================
CREATE OR REPLACE FUNCTION public.generate_recurring_invoices()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
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
        SELECT t.id AS tenant_id, t.property_id, t.room_id,
               t.rent_price, t.end_date, t.profile_id
        FROM public.tenants t
        WHERE t.status = 'active'
          AND t.end_date <= CURRENT_DATE
    LOOP
        -- Calculate next billing period
        v_start_date := (v_tenant.end_date + INTERVAL '1 day')::date;
        v_end_date := (v_start_date + INTERVAL '1 month' - INTERVAL '1 day')::date;
        v_period := to_char(v_start_date, 'YYYY-MM');
        v_due_date := v_start_date;

        -- Idempotent insert (ON CONFLICT DO NOTHING)
        INSERT INTO public.payments (
            property_id,
            tenant_id,
            room_id,
            invoice_number,
            billing_period,
            period_start,
            period_end,
            due_date,
            amount_due,
            amount_paid,
            status,
            is_renewal
        )
        VALUES (
            v_tenant.property_id,
            v_tenant.tenant_id,
            v_tenant.room_id,
            'INV/' || to_char(v_start_date, 'YYYYMM') || '/' || substring(v_tenant.tenant_id::text from 1 for 6),
            v_period,
            v_start_date,
            v_end_date,
            v_due_date,
            COALESCE(v_tenant.rent_price, 0),
            0,
            'unpaid',
            true
        )
        ON CONFLICT (tenant_id, billing_period) DO NOTHING;

        IF FOUND THEN
            v_count := v_count + 1;
            -- Create notification if profile_id is linked
            IF v_tenant.profile_id IS NOT NULL THEN
                INSERT INTO public.notifications (
                    profile_id, title, message, type, data
                ) VALUES (
                    v_tenant.profile_id,
                    'Tagihan Sewa Baru Tersedia',
                    'Tagihan sewa kos periode ' || v_period || ' telah terbit. Silakan lakukan pembayaran.',
                    'invoice_created',
                    jsonb_build_object('billing_period', v_period, 'amount_due', v_tenant.rent_price)
                );
            END IF;
        END IF;
    END LOOP;

    RETURN v_count;
END;
$$;

-- ============================================================================
-- 14. STORED PROCEDURE: apply_rental_renewal(p_payment_id UUID)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.apply_rental_renewal(p_payment_id UUID)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_payment RECORD;
    v_tenant RECORD;
    v_old_end_date DATE;
    v_new_end_date DATE;
BEGIN
    -- 1. Lock and claim the renewal (exactly-once guard)
    UPDATE public.payments
    SET renewal_applied_at = NOW()
    WHERE id = p_payment_id
      AND status = 'paid'
      AND is_renewal = true
      AND renewal_applied_at IS NULL
    RETURNING tenant_id INTO v_payment;

    IF NOT FOUND THEN
        RETURN false;
    END IF;

    -- 2. Lock tenant row
    SELECT id, end_date INTO v_tenant
    FROM public.tenants
    WHERE id = v_payment.tenant_id
      AND status = 'active'
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN false;
    END IF;

    v_old_end_date := v_tenant.end_date;
    v_new_end_date := (v_old_end_date + INTERVAL '1 month')::date;

    -- 3. Extend lease
    UPDATE public.tenants
    SET end_date = v_new_end_date,
        updated_at = NOW()
    WHERE id = v_tenant.id;

    -- 4. Audit trail
    INSERT INTO public.rental_renewals (
        payment_id, tenant_id, previous_end_date, new_end_date
    ) VALUES (
        p_payment_id, v_tenant.id, v_old_end_date, v_new_end_date
    );

    RETURN true;
END;
$$;

-- ============================================================================
-- 15. STORED PROCEDURE: update_overdue_invoices()
-- ============================================================================
CREATE OR REPLACE FUNCTION public.update_overdue_invoices()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_count INTEGER := 0;
BEGIN
    UPDATE public.payments
    SET status = 'overdue',
        updated_at = NOW()
    WHERE status IN ('unpaid', 'partial')
      AND due_date IS NOT NULL
      AND CURRENT_DATE > (due_date + grace_period_days * INTERVAL '1 day')::date;

    GET DIAGNOSTICS v_count = ROW_COUNT;
    RETURN v_count;
END;
$$;

-- ============================================================================
-- 16. TRIGGER: auto-update updated_at on payment_transactions
-- ============================================================================
CREATE OR REPLACE FUNCTION public.update_payment_transactions_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_payment_transactions_updated_at ON public.payment_transactions;
CREATE TRIGGER trg_payment_transactions_updated_at
    BEFORE UPDATE ON public.payment_transactions
    FOR EACH ROW
    EXECUTE FUNCTION public.update_payment_transactions_updated_at();

-- ============================================================================
-- 17. pg_cron SCHEDULED JOBS (run after enabling pg_cron extension)
-- ============================================================================
-- NOTE: pg_cron must be enabled in Supabase Dashboard > Database > Extensions
-- Uncomment and run after enabling the extension:
--
-- SELECT cron.schedule(
--   'generate-recurring-invoices',
--   '5 17 * * *',  -- 00:05 WIB = 17:05 UTC (UTC+7)
--   $$SELECT public.generate_recurring_invoices()$$
-- );
--
-- SELECT cron.schedule(
--   'update-overdue-invoices',
--   '10 17 * * *',  -- 00:10 WIB = 17:10 UTC
--   $$SELECT public.update_overdue_invoices()$$
-- );
