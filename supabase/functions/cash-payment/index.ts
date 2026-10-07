import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createAdminClient, getAuthenticatedUser } from "../_shared/supabase-admin.ts";
import { jsonResponse, errorResponse, corsPreflightResponse } from "../_shared/response-helper.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return corsPreflightResponse();
  try {
    const user = await getAuthenticatedUser(req);
    if (!user) return errorResponse("Unauthorized", 401, "UNAUTHORIZED");
    const { invoice_id } = await req.json();
    if (!invoice_id) return errorResponse("invoice_id is required.");

    const admin = createAdminClient();
    const { data: invoice, error: invoiceError } = await admin.from("payments")
      .select("id, tenant_id, property_id, amount_due, amount_paid, status, billing_period")
      .eq("id", invoice_id).single();
    if (invoiceError || !invoice) return errorResponse("Invoice not found.", 404, "NOT_FOUND");

    const { data: tenant } = await admin.from("tenants")
      .select("id, profile_id, name").eq("id", invoice.tenant_id).single();
    if (!tenant || tenant.profile_id !== user.id) return errorResponse("Forbidden", 403, "FORBIDDEN");
    if (invoice.status === "paid") return errorResponse("Invoice already paid.", 409, "ALREADY_PAID");
    if (invoice.status === "cancelled" || invoice.status === "expired") {
      return errorResponse("Invoice is no longer active.", 409, "INVOICE_CLOSED");
    }

    const netDue = (invoice.amount_due ?? 0) - (invoice.amount_paid ?? 0);
    if (netDue <= 0) return errorResponse("No outstanding amount.", 409, "ALREADY_PAID");

    const { data: existingTx } = await admin.from("payment_transactions")
      .select("id, order_id, status").eq("payment_id", invoice_id)
      .in("status", ["created", "pending", "waiting_confirmation"]).limit(1).maybeSingle();
    if (existingTx) {
      return errorResponse("Masih ada transaksi aktif untuk tagihan ini.", 409, "ACTIVE_TRANSACTION_EXISTS");
    }

    const orderId = `KMC-${invoice_id.substring(0, 8).toUpperCase()}-${Date.now().toString(36).toUpperCase()}`;
    const { data: inserted, error: insertError } = await admin.from("payment_transactions").insert({
      payment_id: invoice_id, tenant_id: invoice.tenant_id, order_id: orderId,
      payment_method: "cash", payment_provider: "manual", gross_amount: netDue,
      status: "waiting_confirmation",
      expires_at: new Date(Date.now() + 7 * 24 * 60 * 60_000).toISOString(),
    }).select().single();

    if (insertError) {
      if (insertError.code === "23505") return errorResponse("Masih ada transaksi aktif untuk tagihan ini.", 409, "ACTIVE_TRANSACTION_EXISTS");
      return errorResponse(`Failed to save transaction: ${insertError.message}`, 500, "DB_ERROR");
    }

    await admin.from("payments").update({ payment_method: "cash", updated_at: new Date().toISOString() }).eq("id", invoice_id);

    const { data: prop } = await admin.from("properties").select("owner_id").eq("id", invoice.property_id).single();
    if (prop?.owner_id) {
      await admin.from("notifications").insert({
        profile_id: prop.owner_id, title: "Konfirmasi Pembayaran Tunai",
        message: `Penghuni ${tenant.name} memilih pembayaran tunai untuk periode ${invoice.billing_period}. Mohon konfirmasi saat dana diterima.`,
        type: "cash_confirmation_required",
        data: { payment_id: invoice_id, transaction_id: inserted.id, tenant_name: tenant.name },
      });
    }

    return jsonResponse({
      transaction_id: inserted.id, order_id: inserted.order_id, payment_method: "cash",
      status: "waiting_confirmation", gross_amount: inserted.gross_amount,
    }, 201);
  } catch (err) {
    console.error("cash-payment error:", err);
    return errorResponse(err instanceof Error ? err.message : "Internal server error", 500, "INTERNAL_ERROR");
  }
});
