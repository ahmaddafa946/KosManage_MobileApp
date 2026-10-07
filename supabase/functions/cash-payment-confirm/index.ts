import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createAdminClient, getAuthenticatedUser } from "../_shared/supabase-admin.ts";
import { jsonResponse, errorResponse, corsPreflightResponse } from "../_shared/response-helper.ts";
import { processPaymentSettlement } from "../_shared/payment-settlement.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return corsPreflightResponse();
  try {
    const user = await getAuthenticatedUser(req);
    if (!user) return errorResponse("Unauthorized", 401, "UNAUTHORIZED");
    const { transaction_id, status } = await req.json();
    if (!transaction_id) return errorResponse("transaction_id is required.");
    if (status !== "paid" && status !== "rejected") return errorResponse('status must be "paid" or "rejected".', 400, "INVALID_STATUS");

    const admin = createAdminClient();
    const { data: tx, error: txError } = await admin.from("payment_transactions")
      .select("id, order_id, payment_method, payment_id, tenant_id, status, payments(property_id, billing_period, status)")
      .eq("id", transaction_id).single();
    if (txError || !tx) return errorResponse("Transaction not found.", 404, "NOT_FOUND");
    if (tx.payment_method !== "cash") return errorResponse("Transaction is not a cash payment.", 400, "INVALID_METHOD");

    const invoice = tx.payments as { property_id: string; billing_period: string; status: string } | null;
    if (!invoice) return errorResponse("Invoice not found.", 404, "INVOICE_NOT_FOUND");
    const { data: prop } = await admin.from("properties").select("owner_id").eq("id", invoice.property_id).single();
    if (!prop || prop.owner_id !== user.id) return errorResponse("Forbidden", 403, "FORBIDDEN");

    if (tx.status === "success" || tx.status === "paid" || invoice.status === "paid") {
      return errorResponse("Already confirmed/paid.", 409, "ALREADY_PAID");
    }
    if (tx.status !== "waiting_confirmation") {
      return errorResponse("Cash transaction is not waiting for confirmation.", 409, "INVALID_TRANSACTION_STATE");
    }

    if (status === "rejected") {
      const { error: rejectError } = await admin.from("payment_transactions")
        .update({ status: "rejected", updated_at: new Date().toISOString() })
        .eq("id", tx.id).eq("status", "waiting_confirmation");
      if (rejectError) throw rejectError;

      const { data: tenant } = await admin.from("tenants").select("profile_id").eq("id", tx.tenant_id).single();
      if (tenant?.profile_id) {
        await admin.from("notifications").insert({
          profile_id: tenant.profile_id,
          title: "Pembayaran Tunai Ditolak",
          message: `Pembayaran tunai periode ${invoice.billing_period} belum dapat dikonfirmasi. Silakan hubungi pemilik kos.`,
          type: "cash_payment_rejected",
          data: { payment_id: tx.payment_id, transaction_id: tx.id },
        });
      }
      return jsonResponse({ status: "rejected" });
    }

    await processPaymentSettlement(admin, tx.order_id, "MANUAL-CASH", "success");
    return jsonResponse({ status: "paid" });
  } catch (err) {
    console.error("cash-payment-confirm error:", err);
    return errorResponse(err instanceof Error ? err.message : "Internal server error", 500, "INTERNAL_ERROR");
  }
});