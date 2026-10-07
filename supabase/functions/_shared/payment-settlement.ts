import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { SupabaseClient } from "npm:@supabase/supabase-js@2";

/**
 * Shared service for idempotent payment settlement.
 * Ensures consistent state across payment_transactions, payments, rental_renewals, and notifications.
 */
export async function processPaymentSettlement(
  admin: SupabaseClient,
  orderId: string,
  gatewayTransactionId: string,
  status: "created" | "success" | "failed" | "expired" | "cancelled" | "pending"
): Promise<void> {
  // 1. Priority-based status resolution
  const STATUS_PRIORITY: Record<string, number> = {
    created: 0,
    pending: 1,
    failed: 2,
    expired: 2,
    cancelled: 2,
    success: 3,
  };

  const { data: tx, error: txError } = await admin
    .from("payment_transactions")
    .select("id, payment_id, tenant_id, status")
    .eq("order_id", orderId)
    .single();

  if (txError || !tx) {
    throw new Error(`Transaction not found for order: ${orderId}`);
  }

  const currentPriority = STATUS_PRIORITY[tx.status] ?? 0;
  const newPriority = STATUS_PRIORITY[status] ?? 0;

  // Never downgrade a terminal success state
  if (newPriority <= currentPriority && tx.status === "success") {
    return; // Already settled, nothing to do
  }

  // 2. Update transaction status
  const txUpdate: Record<string, unknown> = {
    status: status,
    updated_at: new Date().toISOString(),
  };
  if (status === "success") {
    txUpdate.paid_at = new Date().toISOString();
    txUpdate.gateway_reference = gatewayTransactionId;
  }

  const { error: txUpdateError } = await admin
    .from("payment_transactions")
    .update(txUpdate)
    .eq("id", tx.id);

  if (txUpdateError) throw txUpdateError;

  // 3. Handle settlement: update invoice + rental renewal
  if (status === "success") {
    const { data: invoice, error: invoiceError } = await admin
      .from("payments")
      .select("id, tenant_id, amount_due, amount_paid, status, billing_period, is_renewal")
      .eq("id", tx.payment_id)
      .single();

    if (invoiceError) throw invoiceError;

    if (invoice && invoice.status !== "paid") {
      // Update invoice to paid
      const { error: invUpdateError } = await admin
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
        
      if (invUpdateError) throw invUpdateError;

      // Apply rental renewal (exactly-once via stored procedure)
      if (invoice.is_renewal) {
        const { error: rpcError } = await admin.rpc("apply_rental_renewal", { p_payment_id: tx.payment_id });
        if (rpcError) throw rpcError;
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

  // 4. Handle failure/expired: notify tenant
  if ((status === "failed" || status === "expired") && tx.status !== status) {
    const { data: tenantData } = await admin
      .from("tenants")
      .select("profile_id")
      .eq("id", tx.tenant_id)
      .single();

    if (tenantData?.profile_id) {
      const title = status === "failed" ? "Pembayaran Gagal" : "Sesi Pembayaran Kedaluwarsa";
      const message = status === "failed"
        ? "Pembayaran Anda tidak dapat diproses. Silakan coba kembali dengan metode lain."
        : "Waktu pembayaran telah habis. Silakan buat sesi pembayaran baru.";

      await admin.from("notifications").insert({
        profile_id: tenantData.profile_id,
        title,
        message,
        type: status === "failed" ? "payment_failed" : "payment_expired",
        data: { payment_id: tx.payment_id },
      });
    }
  }
}
