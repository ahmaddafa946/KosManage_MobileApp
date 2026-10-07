/**
 * Edge Function: /cash-payment-confirm
 * Owner confirms receipt of cash payment.
 * 
 * Request: POST { transaction_id: string }
 * Security: Requires authenticated owner JWT.
 */
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createAdminClient, getAuthenticatedUser } from "../_shared/supabase-admin.ts";
import { jsonResponse, errorResponse, corsPreflightResponse } from "../_shared/response-helper.ts";
import { processPaymentSettlement } from "../_shared/payment-settlement.ts";

Deno.serve(async (req: Request) => {
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
      .select("id, order_id, payment_method, payment_id, tenant_id, status, gross_amount, payments(property_id, billing_period, amount_due, is_renewal, status)")
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

    if (tx.payment_method !== "cash") {
       return errorResponse("Transaction is not a cash payment.", 400, "INVALID_METHOD");
    }

    if (tx.status === "success" || invoice.status === "paid") {
       return errorResponse("Already confirmed/paid.", 409, "ALREADY_PAID");
    }

    // Use shared settlement logic
    const { status } = body;
    if (status !== "success" && status !== "failed") {
        return errorResponse("Invalid status update.", 400, "INVALID_STATUS");
    }

    await processPaymentSettlement(admin, tx.order_id, "MANUAL-CASH", status);

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
