-- WhatsApp billing reminders (opt-in + owner-approved first message).
-- No payment status is changed by WhatsApp events. Payment remains authoritative in payments/payment_transactions.
ALTER TABLE public.tenants
  ADD COLUMN IF NOT EXISTS whatsapp_billing_opt_in boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS whatsapp_billing_opt_in_at timestamptz,
  ADD COLUMN IF NOT EXISTS whatsapp_billing_opt_out_at timestamptz;

CREATE TABLE IF NOT EXISTS public.whatsapp_billing_outbox (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  payment_id uuid NOT NULL REFERENCES public.payments(id) ON DELETE CASCADE,
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  property_id uuid NOT NULL REFERENCES public.properties(id) ON DELETE CASCADE,
  owner_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'pending_approval'
    CHECK (status IN ('pending_approval','sending','sent','failed','stopped','paid')),
  approved_by uuid REFERENCES auth.users(id),
  approved_at timestamptz,
  first_sent_at timestamptz,
  last_sent_at timestamptz,
  next_reminder_at timestamptz,
  reminder_count integer NOT NULL DEFAULT 0 CHECK (reminder_count >= 0),
  last_message_id text,
  last_error text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT whatsapp_billing_outbox_payment_unique UNIQUE (payment_id)
);

CREATE INDEX IF NOT EXISTS idx_whatsapp_billing_outbox_due
  ON public.whatsapp_billing_outbox (next_reminder_at)
  WHERE status = 'sent';

ALTER TABLE public.whatsapp_billing_outbox ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS whatsapp_billing_owner_read ON public.whatsapp_billing_outbox;
CREATE POLICY whatsapp_billing_owner_read ON public.whatsapp_billing_outbox
  FOR SELECT TO authenticated
  USING (owner_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS whatsapp_billing_tenant_read ON public.whatsapp_billing_outbox;
CREATE POLICY whatsapp_billing_tenant_read ON public.whatsapp_billing_outbox
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.tenants t
      WHERE t.id = whatsapp_billing_outbox.tenant_id
        AND t.profile_id = (SELECT auth.uid())
    )
  );

REVOKE INSERT, UPDATE, DELETE ON public.whatsapp_billing_outbox FROM anon, authenticated;
GRANT SELECT ON public.whatsapp_billing_outbox TO authenticated;

COMMENT ON TABLE public.whatsapp_billing_outbox IS
  'Audit/outbox for owner-approved WhatsApp billing messages. Service role writes; clients are read-only.';
COMMENT ON COLUMN public.tenants.whatsapp_billing_opt_in IS
  'Explicit tenant consent to receive rental billing reminders through WhatsApp.';
