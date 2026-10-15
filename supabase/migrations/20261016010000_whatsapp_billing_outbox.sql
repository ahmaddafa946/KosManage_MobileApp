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


-- Inbound Cloud API webhook deduplication and processing lease.
-- Only trusted Edge Functions using service_role may read/write these records.
CREATE TABLE IF NOT EXISTS public.whatsapp_billing_inbound_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id text NOT NULL UNIQUE,
  from_phone text NOT NULL,
  message_type text NOT NULL DEFAULT 'unknown',
  status text NOT NULL DEFAULT 'received'
    CHECK (status IN ('received', 'processing', 'processed', 'ignored', 'failed')),
  attempt_count integer NOT NULL DEFAULT 0 CHECK (attempt_count >= 0),
  processing_started_at timestamptz,
  received_at timestamptz NOT NULL DEFAULT now(),
  processed_at timestamptz,
  updated_at timestamptz NOT NULL DEFAULT now(),
  last_error text
);

CREATE INDEX IF NOT EXISTS idx_whatsapp_billing_inbound_recovery
  ON public.whatsapp_billing_inbound_events (status, processing_started_at)
  WHERE status IN ('received', 'processing', 'failed');

ALTER TABLE public.whatsapp_billing_inbound_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.whatsapp_billing_inbound_events FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.whatsapp_billing_inbound_events TO service_role;
GRANT INSERT, SELECT, UPDATE, DELETE ON public.whatsapp_billing_outbox TO service_role;

ALTER TABLE public.whatsapp_billing_outbox
  ADD COLUMN IF NOT EXISTS last_delivery_status text
    CHECK (last_delivery_status IS NULL OR last_delivery_status IN ('sent', 'delivered', 'read', 'failed')),
  ADD COLUMN IF NOT EXISTS last_status_at timestamptz;

-- Look up a single active tenant by normalized phone digits without loading contact
-- lists into the Edge Function. The function is intentionally callable only by service_role.
CREATE OR REPLACE FUNCTION public.find_tenant_by_whatsapp_phone(p_phone text)
RETURNS TABLE (
  id uuid,
  name text,
  phone text,
  email text,
  profile_id uuid,
  property_id uuid,
  whatsapp_billing_opt_in boolean
)
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public, pg_temp
AS $function$
  WITH input_number AS (
    SELECT CASE
      WHEN normalized LIKE '0%' THEN '62' || substr(normalized, 2)
      ELSE normalized
    END AS digits
    FROM (SELECT regexp_replace(COALESCE(p_phone, ''), '[^0-9]', '', 'g') AS normalized) raw
  ),
  tenant_numbers AS (
    SELECT
      t.id, t.name, t.phone, t.email, t.profile_id, t.property_id,
      t.whatsapp_billing_opt_in,
      CASE
        WHEN normalized LIKE '0%' THEN '62' || substr(normalized, 2)
        ELSE normalized
      END AS digits
    FROM public.tenants t
    CROSS JOIN LATERAL (
      SELECT regexp_replace(COALESCE(t.phone, ''), '[^0-9]', '', 'g') AS normalized
    ) raw
    WHERE t.status = 'active'
  )
  SELECT t.id, t.name, t.phone, t.email, t.profile_id, t.property_id, t.whatsapp_billing_opt_in
  FROM tenant_numbers t
  CROSS JOIN input_number i
  WHERE t.digits = i.digits AND i.digits <> ''
  LIMIT 2;
$function$;

REVOKE ALL ON FUNCTION public.find_tenant_by_whatsapp_phone(text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.find_tenant_by_whatsapp_phone(text) TO service_role;
