# WhatsApp Billing — Setup & Operations

This feature adds an owner-approved first WhatsApp billing message and up to three scheduled reminders. It does not mark invoices paid and does not replace the existing payment gateway/webhook flow.

## Required Meta setup

1. Set up a Meta Business Portfolio, WhatsApp Business Account, and registered Cloud API phone number.
2. Create and get approval for a WhatsApp **utility** template named in `WHATSAPP_BILLING_TEMPLATE_NAME`, with language `id` (or configure another language).
3. Template body must contain four text placeholders, in this exact order:
   - tenant name
   - invoice number (falls back to billing period)
   - outstanding amount
   - due date
4. Configure tenant consent and save the consent timestamp only after the tenant has explicitly opted in. Default consent is false.

## Supabase Edge Function secrets

Configure these in Supabase Dashboard → Edge Functions → Secrets. Never put them in Flutter or commit them.

- `WHATSAPP_ACCESS_TOKEN`: Meta system-user access token with messaging permissions.
- `WHATSAPP_PHONE_NUMBER_ID`: Cloud API phone-number ID, not the visible phone number.
- `WHATSAPP_API_VERSION`: supported Graph API version for your Meta app (for example, the currently supported version selected in Meta dashboard).
- `WHATSAPP_BILLING_TEMPLATE_NAME`: approved utility template name.
- `WHATSAPP_TEMPLATE_LANGUAGE`: optional, defaults to `id`.
- `WHATSAPP_REMINDER_CRON_SECRET`: high-entropy random secret used only by the scheduled reminder invocation.

## Deploy

Deploy `whatsapp-billing` with JWT verification enabled at the gateway; the function additionally verifies the owner JWT for `approve-invoice`. The scheduled `run-reminders` action uses the separate secret bearer token and must not be callable without it.

## API

Owner approval:
```json
{ "action": "approve-invoice", "invoice_id": "<payments.id>" }
```
Call with the signed-in owner's Supabase JWT. It verifies ownership, open balance, tenant phone, and explicit opt-in before sending the first approved template message. Duplicate approval is rejected. A failed send can be retried by owner.

Scheduled reminder:
```json
{ "action": "run-reminders" }
```
Call from a trusted scheduler with `Authorization: Bearer <WHATSAPP_REMINDER_CRON_SECRET>`. Schedule it every day; it sends only when `next_reminder_at` is due, stops after three reminders, and stops reminders for paid/closed invoices or missing consent.

## Important limitations

- This first slice sends approved template messages only. It does not yet implement inbound WhatsApp replies, interactive payment selection, or WhatsApp delivery-status webhooks.
- Transfer and cash remain in the existing payment flows. The existing Midtrans functions remain responsible for QRIS/VA transactions and verified gateway settlement.
- Do not enable scheduled reminders until the migration is applied, secrets are set, template is approved, tenant consent is collected, and a test phone has passed end-to-end verification.
- The Meta API accepting a message means it was accepted for processing, not necessarily delivered.
