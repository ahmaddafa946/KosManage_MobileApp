# WhatsApp Billing — Setup & Operations

This feature adds an owner-approved first WhatsApp billing message and up to three scheduled reminders. It does not mark invoices paid and does not replace the existing payment gateway/webhook flow.

## Required Meta setup

1. Set up a Meta Business Portfolio, WhatsApp Business Account, and registered Cloud API phone number.
2. Create and get approval for a WhatsApp **utility** template named in `WHATSAPP_BILLING_TEMPLATE_NAME`, with language `id` (or configure another language).
3. Template body must contain four text placeholders, in this exact order: tenant name, invoice number (falls back to billing period), outstanding amount, and due date.
4. Tenant consent is off by default. The tenant can opt in/out through the authenticated `whatsapp-billing-consent` function; only call opt-in after the tenant has explicitly agreed.

## Supabase Edge Function secrets

Configure these in Supabase Dashboard → Edge Functions → Secrets. Never put them in Flutter or commit them.

- `WHATSAPP_ACCESS_TOKEN`: Meta system-user access token with messaging permissions.
- `WHATSAPP_PHONE_NUMBER_ID`: Cloud API phone-number ID, not the visible phone number.
- `WHATSAPP_API_VERSION`: supported Graph API version for your Meta app.
- `WHATSAPP_BILLING_TEMPLATE_NAME`: approved utility template name.
- `WHATSAPP_TEMPLATE_LANGUAGE`: optional, defaults to `id`.
- `WHATSAPP_REMINDER_CRON_SECRET`: high-entropy random secret used only by the scheduled reminder invocation.

## Deploy and authentication

- Deploy `whatsapp-billing` with platform JWT verification **disabled** because it supports both a trusted scheduler and user JWTs. The function itself validates user JWTs with Supabase Auth for `approve-invoice`; `run-reminders` requires the separate secret bearer token. Do not expose the cron secret to Flutter.
- Deploy `whatsapp-billing-consent` with platform JWT verification enabled. It additionally validates the signed-in user and only changes the tenant row linked to that user's profile.
- Apply the migration before deploying these functions.

## API

Tenant opt-in/out (call with tenant's Supabase JWT):
```json
{ "opt_in": true }
```
Use `false` to withdraw consent; pending reminders are stopped.

Owner approval (call with owner's Supabase JWT):
```json
{ "action": "approve-invoice", "invoice_id": "<payments.id>" }
```
It verifies ownership, open balance, tenant phone, and explicit opt-in before sending the first approved template message. Duplicate approval is rejected. A failed send can be retried by owner.

Scheduled reminder (trusted scheduler only):
```json
{ "action": "run-reminders" }
```
Call with `Authorization: Bearer <WHATSAPP_REMINDER_CRON_SECRET>`. Schedule it daily; it sends only when `next_reminder_at` is due, stops after three successful reminders, and stops reminders for paid/closed invoices or withdrawn consent. Due rows are claimed with a conditional database update so concurrent scheduler runs do not normally send the same reminder twice. Failed sends/read operations are retried after 24 hours without incrementing the successful reminder count. Stale reminder claims older than 15 minutes are recovered after an interrupted run.

## Important limitations before production

- This slice sends approved template messages only. It does not yet implement inbound WhatsApp replies, interactive payment selection, WhatsApp delivery-status webhooks, or a dedicated Flutter consent/approval UI.
- Transfer and cash remain in the existing payment flows. Existing Midtrans functions remain responsible for QRIS/VA transactions and verified gateway settlement.
- Do not enable scheduled reminders until the migration is applied, secrets are set, template is approved, tenant consent is collected, and a test phone has passed end-to-end verification.
- The Meta API accepting a message means it was accepted for processing, not necessarily delivered.
