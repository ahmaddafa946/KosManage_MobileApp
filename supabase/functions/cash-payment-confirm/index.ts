/**
 * Edge Function: /cash-payment-confirm
 * Owner confirms receipt of cash payment.
 * 
 * Request: POST { transaction_id: string }
 * Security: Requires authenticated owner JWT.
 */
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createAdminClient, getAuthenticatedUser } from "../_shared/supabase-admin.ts";
import { jsonResponse, errorResponse, corsPreflightResponse } from "../_shared/response-helper.ts";

serve(async (req: Request) => {
  if (req.method === "OPTIONS") return corsPreflightResponse();

  try {
    const user = await getAuthenticatedUser(req);
    if (!user) return errorResponse("Unauthorized", 401, "UNAUTHORIZED");

    const body = await req.json();
    const { transaction_id } = body;

    if (!transaction_id) {
      return errorResponse("transaction_id is required.");
    }

    const admin = createAdminClient();

    // 1. Fetch transaction and invoice
    const { data: tx, error: txError } = await admin
      .from("payment_transactions")
      .select("id, payment_id, tenant_id, status, gross_amount, payments(property_id, billing_period, amount_due, is_renewal, status)")
      .eq("id", transaction_id)
      .single();

    if (txError || !tx) {
      return errorResponse("Transaction not found.", 404, "NOT_FOUND");
    }

    // deno-lint-ignore no-explicit-any
    const invoice = tx.payments as any;

    // 2. Verify owner owns this property
    const { data: prop } = await admin
      .from("properties")
      .select("owner_id")
      .eq("id", invoice.property_id)
      .single();

    if (!prop || prop.owner_id !== user.id) {
      return errorResponse("Forbidden", 403, "FORBIDDEN");
    }

    if (tx.status === "success" || invoice.status === "paid") {
       return errorResponse("Already confirmed/paid.", 409, "ALREADY_PAID");
    }

    // 3. Mark transaction as success
    await admin
      .from("payment_transactions")
      .update({
        status: "success",
        paid_at: new Date().toISOString(),
        gateway_reference: "MANUAL-CASH",
        updated_at: new Date().toISOString()
      })
      .eq("id", tx.id);

    // 4. Update invoice to paid
    await admin
      .from("payments")
      .update({
        status: "paid",
        amount_paid: invoice.amount_due,
        paid_at: new Date().toISOString(),
        payment_date: new Date().toISOString().split("T")[0],
        payment_reference: tx.id,
        updated_at: new Date().toISOString(),
      })
      .eq("id", tx.payment_id);

    // 5. Apply rental renewal
    if (invoice.is_renewal) {
      await admin.rpc("apply_rental_renewal", { p_payment_id: tx.payment_id });
    }

    // 6. Notify Tenant
    const { data: tenantData } = await admin
      .from("tenants")
      .select("profile_id")
      .eq("id", tx.tenant_id)
      .single();

    if (tenantData?.profile_id) {
      await admin.from("notifications").insert({
        profile_id: tenantData.profile_id,
        title: "Pembayaran Dikonfirmasi",
        message: `Pemilik kos telah mengonfirmasi pembayaran tunai Anda untuk periode ${invoice.billing_period}.`,
        type: "payment_success",
        data: {
          payment_id: tx.payment_id,
          billing_period: invoice.billing_period,
        },
      });
    }

    return jsonResponse({ status: "success" });

  } catch (err) {
    console.error("cash-payment-confirm error:", err);
    return errorResponse(
      err instanceof Error ? err.message : "Internal server error",
      500,
      "INTERNAL_ERROR",
    );
  }
});
