/**
 * Edge Function: /payment-webhook
 * Receives and processes Midtrans webhook notifications.
 * 
 * This is a PUBLIC endpoint (no auth required) but validates SHA-512 signature.
 * Handles: settlement, deny, cancel, expire, failure, pending
 */
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createAdminClient } from "../_shared/supabase-admin.ts";
import { getPaymentGateway } from "../_shared/midtrans-provider.ts";
import { jsonResponse, errorResponse, corsPreflightResponse } from "../_shared/response-helper.ts";
import { processPaymentSettlement } from "../_shared/payment-settlement.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return corsPreflightResponse();

  try {
    const rawBody = await req.json();
    const gateway = getPaymentGateway();

    // 1. Verify webhook signature (SHA-512)
    const verification = await gateway.verifyWebhook(rawBody);
    if (!verification.isValid) {
      console.error("Webhook signature verification FAILED for order:", verification.orderId);
      return errorResponse("Invalid signature", 401, "INVALID_SIGNATURE");
    }

    const admin = createAdminClient();
    const { orderId, transactionId, transactionStatus, grossAmount } = verification;

    // 2. Idempotency check: has this exact event been processed?
    const { data: existingEvent } = await admin
      .from("payment_webhook_events")
      .select("id")
      .eq("order_id", orderId)
      .eq("transaction_status", transactionStatus)
      .maybeSingle();

    if (existingEvent) {
      // Already processed, return 200 to stop Midtrans retries
      return jsonResponse({ status: "ok", message: "Event already processed" });
    }

    // 3. Record webhook event (idempotency guard via UNIQUE constraint)
    const { error: eventInsertError } = await admin
      .from("payment_webhook_events")
      .insert({
        order_id: orderId,
        event_type: `payment.${transactionStatus}`,
        transaction_status: transactionStatus,
        signature_key: String(rawBody.signature_key ?? ""),
        raw_payload: rawBody,
      });

    if (eventInsertError) {
      // Constraint violation = duplicate, which is fine
      if (eventInsertError.code === "23505") {
        return jsonResponse({ status: "ok", message: "Event already processed" });
      }
      console.error("Failed to insert webhook event:", eventInsertError);
    }

    // 4. Map status and execute shared settlement logic
    const mapGatewayStatus = (s: string): "success" | "pending" | "failed" | "expired" | "cancelled" | "created" => {
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
    };

    const newStatus = mapGatewayStatus(transactionStatus);
    
    // Process settlement, this handles all db updates, priorities, idempotency, etc.
    await processPaymentSettlement(admin, orderId, transactionId || orderId, newStatus as any);

    return jsonResponse({ status: "ok" });
  } catch (err) {
    console.error("payment-webhook error:", err);
    // MUST return 500 for internal errors so Midtrans can retry.
    return errorResponse(
      err instanceof Error ? err.message : "Internal Server Error",
      500,
      "INTERNAL_ERROR"
    );
  }
});
