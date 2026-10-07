import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { SupabaseClient } from "npm:@supabase/supabase-js@2";

type SettlementStatus =
  | "created"
  | "pending"
  | "success"
  | "failed"
  | "expired"
  | "cancelled";

const STATUS_PRIORITY: Record<SettlementStatus, number> = {
  created: 0,
  pending: 1,
  failed: 2,
  expired: 2,
  cancelled: 2,
  success: 3,
};

export async function processPaymentSettlement(
  admin: SupabaseClient,
  orderId: string,
  gatewayTransactionId: string,
  status: SettlementStatus,
): Promise<void> {
  const { data: tx, error: txError } = await admin
    .from("payment_transactions")
    .select("id, payment_id, tenant_id, status")
    .eq("order_id", orderId)
    .single();

  if (txError || !tx) {
    throw new Error(`Transaction not found for order: ${orderId}`);
  }

  const currentStatus = tx.status as string;
  const currentPriority = STATUS_PRIORITY[currentStatus as SettlementStatus] ?? 0;
  const newPriority = STATUS_PRIORITY[status];

  if (currentStatus === "success" && status !== "success") return;
  if (status !== "success" && newPriority < currentPriority) return;

  const now = new Date().toISOString();

  if (status === "success") {
    const { error: txUpdateError } = await admin
      .from("payment_transactions")
      .update({
        status: "success",
        paid_at: now,
        gateway_reference: gatewayTransactionId,
        updated_at: now,
      })
      .eq("id", tx.id);

    if (txUpdateError) throw txUpdateError;

    const { data: invoice, error: invoiceError } = await admin
      .from("payments")
      .select("id, tenant_id, property_id, amount_due, status, billing_period, is_renewal")
      .eq("id", tx.payment_id)
      .single();

    if (invoiceError || !invoice) {
      throw invoiceError ?? new Error("Invoice not found during settlement");
    }

    const wasAlreadyPaid = invoice.status === "paid";

    if (!wasAlreadyPaid) {
      const { error: invUpdateError } = await admin
        .from("payments")
        .update({
          status: "paid",
          amount_paid: invoice.amount_due,
          paid_at: now,
          payment_date: now.split("T")[0],
          payment_reference: orderId,
          updated_at: now,
        })
        .eq("id", tx.payment_id)
        .neq("status", "paid");

      if (invUpdateError) throw invUpdateError;
    }

    if (invoice.is_renewal) {
      const { error: rpcError } = await admin.rpc("apply_rental_renewal", {
        p_payment_id: tx.payment_id,
      });
      if (rpcError) throw rpcError;
    }

    if (!wasAlreadyPaid) {
      const { data: tenantData } = await admin
        .from("tenants")
        .select("profile_id")
        .eq("id", tx.tenant_id)
        .single();

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

      const { data: prop } = await admin
        .from("properties")
        .select("owner_id")
        .eq("id", invoice.property_id)
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

    return;
  }

  const { error: txUpdateError } = await admin
    .from("payment_transactions")
    .update({ status, updated_at: now })
    .eq("id", tx.id);

  if (txUpdateError) throw txUpdateError;

  if (status === "failed" || status === "expired") {
    const { data: tenantData } = await admin
      .from("tenants")
      .select("profile_id")
      .eq("id", tx.tenant_id)
      .single();

    if (tenantData?.profile_id) {
      await admin.from("notifications").insert({
        profile_id: tenantData.profile_id,
        title: status === "failed" ? "Pembayaran Gagal" : "Sesi Pembayaran Kedaluwarsa",
        message: status === "failed"
          ? "Pembayaran Anda tidak dapat diproses. Silakan coba kembali dengan metode lain."
          : "Waktu pembayaran telah habis. Silakan buat sesi pembayaran baru.",
        type: status === "failed" ? "payment_failed" : "payment_expired",
        data: { payment_id: tx.payment_id },
      });
    }
  }
}
