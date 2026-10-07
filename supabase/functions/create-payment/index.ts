/**
 * Edge Function: /create-payment
 * Creates a payment transaction (QRIS or Bank Transfer) for a given invoice.
 * 
 * Request: POST { invoice_id: string, payment_method: 'qris' | 'bank_transfer', bank?: string }
 * Security: Requires authenticated tenant JWT. Amount is NEVER sent from client.
 */
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createAdminClient, getAuthenticatedUser } from "../_shared/supabase-admin.ts";
import { getPaymentGateway } from "../_shared/midtrans-provider.ts";
import {
  jsonResponse,
  errorResponse,
  corsPreflightResponse,
} from "../_shared/response-helper.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return corsPreflightResponse();

  try {
    // 1. Authenticate user
    const user = await getAuthenticatedUser(req);
    if (!user) return errorResponse("Unauthorized", 401, "UNAUTHORIZED");

    // 2. Parse request body
    const body = await req.json();
    const { invoice_id, payment_method, bank } = body;

    if (!invoice_id || !payment_method) {
      return errorResponse("invoice_id and payment_method are required.");
    }
    if (!["qris", "bank_transfer"].includes(payment_method)) {
      return errorResponse("Invalid payment_method. Use 'qris' or 'bank_transfer'.");
    }
    if (payment_method === "bank_transfer" && !bank) {
      return errorResponse("bank is required for bank_transfer method.");
    }

    const admin = createAdminClient();

    // 3. Fetch the invoice from database (server-authoritative amount)
    const { data: invoice, error: invoiceError } = await admin
      .from("payments")
      .select("id, tenant_id, property_id, room_id, billing_period, amount_due, amount_paid, status")
      .eq("id", invoice_id)
      .single();

    if (invoiceError || !invoice) {
      return errorResponse("Invoice not found.", 404, "NOT_FOUND");
    }

    // 4. Verify tenant owns this invoice
    const { data: tenant } = await admin
      .from("tenants")
      .select("id, name, profile_id, email, phone")
      .eq("id", invoice.tenant_id)
      .single();

    if (!tenant || (tenant.profile_id !== user.id)) {
      return errorResponse("You do not have access to this invoice.", 403, "FORBIDDEN");
    }

    // 5. Validate invoice status
    if (invoice.status === "paid") {
      return errorResponse("Invoice already paid.", 409, "ALREADY_PAID");
    }
    if (invoice.status === "cancelled" || invoice.status === "expired") {
      return errorResponse("Invoice is no longer active.", 409, "INVOICE_CLOSED");
    }

    const netDue = (invoice.amount_due ?? 0) - (invoice.amount_paid ?? 0);
    if (netDue <= 0) {
      return errorResponse("No outstanding amount.", 409, "ALREADY_PAID");
    }

    // 6. Cancel any existing pending transaction for this invoice
    const { data: existingTx } = await admin
      .from("payment_transactions")
      .select("id, order_id, status")
      .eq("payment_id", invoice_id)
      .in("status", ["created", "pending"])
      .limit(1)
      .maybeSingle();

    if (existingTx) {
      return errorResponse(
        "Masih ada transaksi aktif untuk tagihan ini. Silakan selesaikan atau batalkan transaksi sebelumnya.",
        409,
        "ACTIVE_TRANSACTION_EXISTS"
      );
    }

    // 7. Generate unique order_id
    const txSuffix = Date.now().toString(36).toUpperCase();
    const orderId = `KM-${invoice_id.substring(0, 8).toUpperCase()}-${txSuffix}`;

    // 8. Fetch room info for item description
    let roomNumber = "Kos";
    if (invoice.room_id) {
      const { data: room } = await admin
        .from("rooms")
        .select("room_number")
        .eq("id", invoice.room_id)
        .single();
      if (room) roomNumber = `Kamar ${room.room_number}`;
    }

    // 9. Call payment gateway
    const gateway = getPaymentGateway();
    const chargeParams = {
      orderId,
      grossAmount: netDue,
      customerDetails: {
        firstName: tenant.name ?? "Tenant",
        email: tenant.email ?? user.email ?? "tenant@kosmanage.app",
        phone: tenant.phone,
      },
      itemDetails: [
        {
          id: invoice.room_id ?? invoice_id,
          price: netDue,
          quantity: 1,
          name: `Sewa ${roomNumber} Periode ${invoice.billing_period}`,
        },
      ],
    };

    let txRecord: Record<string, unknown>;

    if (payment_method === "qris") {
      const result = await gateway.createQrPayment(chargeParams);
      txRecord = {
        payment_id: invoice_id,
        tenant_id: invoice.tenant_id,
        order_id: orderId,
        payment_method: "qris",
        payment_provider: "midtrans",
        gross_amount: netDue,
        status: "pending",
        qr_string: result.qrString,
        qr_url: result.qrImageUrl ?? null,
        gateway_reference: result.transactionId,
        expires_at: result.expiresAt,
        payload_response: result.rawResponse,
      };
    } else {
      const result = await gateway.createBankTransfer(chargeParams, bank);
      txRecord = {
        payment_id: invoice_id,
        tenant_id: invoice.tenant_id,
        order_id: orderId,
        payment_method: "bank_transfer",
        payment_provider: "midtrans",
        gross_amount: netDue,
        status: "pending",
        va_number: result.vaNumber,
        bank: result.bank,
        gateway_reference: result.transactionId,
        expires_at: result.expiresAt,
        payload_response: result.rawResponse,
      };
    }

    // 10. Insert transaction record
    const { data: inserted, error: insertError } = await admin
      .from("payment_transactions")
      .insert(txRecord)
      .select()
      .single();

    if (insertError) {
      return errorResponse(`Failed to save transaction: ${insertError.message}`, 500, "DB_ERROR");
    }

    // 11. Keep the legacy invoice payment_method enum compatible:
    // QRIS is e-wallet, while VA/bank transfer is transfer.
    const invoicePaymentMethod = payment_method === "qris" ? "ewallet" : "transfer";
    const { error: invoiceMethodError } = await admin
      .from("payments")
      .update({ payment_method: invoicePaymentMethod, updated_at: new Date().toISOString() })
      .eq("id", invoice_id);
    if (invoiceMethodError) throw invoiceMethodError;

    // 12. Return transaction details to client
    return jsonResponse({
      transaction_id: inserted.id,
      order_id: inserted.order_id,
      payment_method: inserted.payment_method,
      gross_amount: inserted.gross_amount,
      status: inserted.status,
      qr_string: inserted.qr_string ?? null,
      qr_url: inserted.qr_url ?? null,
      va_number: inserted.va_number ?? null,
      bank: inserted.bank ?? null,
      expires_at: inserted.expires_at,
    }, 201);
  } catch (err) {
    console.error("create-payment error:", err);
    return errorResponse(
      err instanceof Error ? err.message : "Internal server error",
      500,
      "INTERNAL_ERROR",
    );
  }
});
