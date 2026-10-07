import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createAdminClient } from "../_shared/supabase-admin.ts";
import { getPaymentGateway } from "../_shared/midtrans-provider.ts";
import { jsonResponse, errorResponse, corsPreflightResponse } from "../_shared/response-helper.ts";
import { processPaymentSettlement } from "../_shared/payment-settlement.ts";

type SettlementStatus = "created" | "pending" | "success" | "failed" | "expired" | "cancelled";

function mapGatewayStatus(s: string): SettlementStatus {
  switch (s) {
    case "settlement":
    case "capture":
      return "success";
    case "pending":
      return "pending";
    case "deny":
    case "failure":
      return "failed";
    case "expire":
      return "expired";
    case "cancel":
      return "cancelled";
    default:
      return "created";
  }
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return corsPreflightResponse();

  try {
    const rawBody = await req.json();
    const gateway = getPaymentGateway();
    const verification = await gateway.verifyWebhook(rawBody);

    if (!verification.isValid) {
      console.error("Webhook signature verification FAILED for order:", verification.orderId);
      return errorResponse("Invalid signature", 401, "INVALID_SIGNATURE");
    }

    const admin = createAdminClient();
    const { orderId, transactionId, transactionStatus } = verification;
    const newStatus = mapGatewayStatus(transactionStatus);

    // Reconcile first. We intentionally record the webhook event only after
    // settlement succeeds. Otherwise a transient DB error could mark an event
    // as processed and prevent Midtrans from retrying it.
    await processPaymentSettlement(admin, orderId, transactionId || orderId, newStatus);

    // Idempotency audit record. Concurrent duplicate webhooks are safe because
    // the unique constraint accepts only one event; settlement itself is
    // idempotent and can safely run before this insert.
    const { error: eventInsertError } = await admin
      .from("payment_webhook_events")
      .insert({
        order_id: orderId,
        event_type: `payment.${transactionStatus}`,
        transaction_status: transactionStatus,
        signature_key: String(rawBody.signature_key ?? ""),
        raw_payload: rawBody,
      });

    if (eventInsertError && eventInsertError.code !== "23505") {
      throw eventInsertError;
    }

    return jsonResponse({ status: "ok" });
  } catch (err) {
    console.error("payment-webhook error:", err);
    return errorResponse(
      err instanceof Error ? err.message : "Internal Server Error",
      500,
      "INTERNAL_ERROR",
    );
  }
});