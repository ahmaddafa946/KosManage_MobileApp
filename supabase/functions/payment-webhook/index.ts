/**
 * Edge Function: /payment-webhook
 * Receives and processes Midtrans webhook notifications.
 * 
 * This is a PUBLIC endpoint (no auth required) but validates SHA-512 signature.
 * Handles: settlement, deny, cancel, expire, failure, pending
 */
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createAdminClient } from "../_shared/supabase-admin.ts";
import { getPaymentGateway } from "../_shared/midtrans-provider.ts";
import { jsonResponse, errorResponse, corsPreflightResponse } from "../_shared/response-helper.ts";

serve(async (req: Request) => {
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

    // 4. Lookup the transaction
    const { data: tx, error: txError } = await admin
      .from("payment_transactions")
      .select("id, payment_id, tenant_id, status")
      .eq("order_id", orderId)
      .single();

    if (txError || !tx) {
      console.error("Transaction not found for order:", orderId);
      // Still return 200 to prevent Midtrans retries
      return jsonResponse({ status: "ok", message: "Transaction not found, event logged" });
    }

    // 5. Priority-based status resolution
    const STATUS_PRIORITY: Record<string, number> = {
      created: 0,
      pending: 1,
      failed: 2,
      expired: 2,
      cancelled: 2,
      success: 3,
    };

    const mapGatewayStatus = (s: string): string => {
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
          return s;
      }
    };

    const newStatus = mapGatewayStatus(transactionStatus);
    const currentPriority = STATUS_PRIORITY[tx.status] ?? 0;
    const newPriority = STATUS_PRIORITY[newStatus] ?? 0;

    // Never downgrade a terminal success state
    if (newPriority <= currentPriority && tx.status === "success") {
      return jsonResponse({ status: "ok", message: "Ignored: transaction already settled" });
    }

    // 6. Update transaction status
    const txUpdate: Record<string, unknown> = {
      status: newStatus,
      updated_at: new Date().toISOString(),
    };
    if (newStatus === "success") {
      txUpdate.paid_at = new Date().toISOString();
      txUpdate.gateway_reference = transactionId;
    }

    await admin
      .from("payment_transactions")
      .update(txUpdate)
      .eq("id", tx.id);

    // 7. Handle settlement: update invoice + rental renewal
    if (newStatus === "success") {
      // Fetch invoice for notification
      const { data: invoice } = await admin
        .from("payments")
        .select("id, tenant_id, amount_due, amount_paid, status, billing_period, is_renewal")
        .eq("id", tx.payment_id)
        .single();

      if (invoice && invoice.status !== "paid") {
        // Update invoice to paid
        await admin
          .from("payments")
          .update({
            status: "paid",
            amount_paid: invoice.amount_due,
            paid_at: new Date().toISOString(),
            payment_date: new Date().toISOString().split("T")[0],
            payment_reference: orderId,
            updated_at: new Date().toISOString(),
          })
          .eq("id", tx.payment_id);

        // Apply rental renewal (exactly-once via stored procedure)
        if (invoice.is_renewal) {
          await admin.rpc("apply_rental_renewal", { p_payment_id: tx.payment_id });
        }

        // Get tenant profile_id for notifications
        const { data: tenantData } = await admin
          .from("tenants")
          .select("profile_id")
          .eq("id", tx.tenant_id)
          .single();

        // Create success notification for tenant
        if (tenantData?.profile_id) {
          await admin.from("notifications").insert({
            profile_id: tenantData.profile_id,
            title: "Pembayaran Berhasil!",
            message: `Pembayaran sewa periode ${invoice.billing_period} telah berhasil dikonfirmasi.`,
            type: "payment_success",
            data: {
              payment_id: tx.payment_id,
              billing_period: invoice.billing_period,
              amount: invoice.amount_due,
            },
          });
        }

        // Notify owner
        const { data: property } = await admin
          .from("payments")
          .select("property_id")
          .eq("id", tx.payment_id)
          .single();

        if (property) {
          const { data: prop } = await admin
            .from("properties")
            .select("owner_id")
            .eq("id", property.property_id)
            .single();

          if (prop?.owner_id) {
            await admin.from("notifications").insert({
              profile_id: prop.owner_id,
              title: "Pembayaran Diterima",
              message: `Tagihan periode ${invoice.billing_period} telah dibayar oleh penghuni.`,
              type: "payment_received",
              data: {
                payment_id: tx.payment_id,
                billing_period: invoice.billing_period,
                amount: invoice.amount_due,
              },
            });
          }
        }
      }
    }

    // 8. Handle failure/expired: notify tenant
    if (newStatus === "failed" || newStatus === "expired") {
      const { data: tenantData } = await admin
        .from("tenants")
        .select("profile_id")
        .eq("id", tx.tenant_id)
        .single();

      if (tenantData?.profile_id) {
        const title = newStatus === "failed" ? "Pembayaran Gagal" : "Sesi Pembayaran Kedaluwarsa";
        const message = newStatus === "failed"
          ? "Pembayaran Anda tidak dapat diproses. Silakan coba kembali dengan metode lain."
          : "Waktu pembayaran telah habis. Silakan buat sesi pembayaran baru.";

        await admin.from("notifications").insert({
          profile_id: tenantData.profile_id,
          title,
          message,
          type: newStatus === "failed" ? "payment_failed" : "payment_expired",
          data: { payment_id: tx.payment_id },
        });
      }
    }

    return jsonResponse({ status: "ok" });
  } catch (err) {
    console.error("payment-webhook error:", err);
    // Return 200 even on internal error to prevent infinite Midtrans retries
    return jsonResponse({ status: "ok", message: "Processed with errors" });
  }
});
