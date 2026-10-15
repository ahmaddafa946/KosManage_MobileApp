import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createAdminClient, getAuthenticatedUser } from "../_shared/supabase-admin.ts";
import { corsPreflightResponse, errorResponse, jsonResponse } from "../_shared/response-helper.ts";

type Invoice = {
  id: string; tenant_id: string; property_id: string; billing_period: string;
  invoice_number: string | null; due_date: string | null; amount_due: number;
  amount_paid: number; status: string;
};
type Tenant = {
  id: string; name: string | null; phone: string | null; profile_id: string | null;
  whatsapp_billing_opt_in: boolean;
};

const jsonHeaders = { "content-type": "application/json; charset=utf-8" };

function rupiah(value: number): string {
  return new Intl.NumberFormat("id-ID", { style: "currency", currency: "IDR", maximumFractionDigits: 0 }).format(value);
}
function normalizePhone(value: string): string | null {
  const digits = value.replace(/[^0-9]/g, "").replace(/^0/, "62");
  return digits.length >= 10 && digits.length <= 15 ? digits : null;
}
async function sendTemplate(to: string, invoice: Invoice, tenant: Tenant): Promise<string> {
  const token = Deno.env.get("WHATSAPP_ACCESS_TOKEN");
  const phoneId = Deno.env.get("WHATSAPP_PHONE_NUMBER_ID");
  const version = Deno.env.get("WHATSAPP_API_VERSION");
  const templateName = Deno.env.get("WHATSAPP_BILLING_TEMPLATE_NAME");
  const language = Deno.env.get("WHATSAPP_TEMPLATE_LANGUAGE") ?? "id";
  if (!token || !phoneId || !version || !templateName) {
    throw new Error("WhatsApp configuration is incomplete.");
  }
  const recipient = normalizePhone(to);
  if (!recipient) throw new Error("Nomor WhatsApp tenant tidak valid.");

  const dueDate = invoice.due_date
    ? new Intl.DateTimeFormat("id-ID", { dateStyle: "long", timeZone: "Asia/Jakarta" }).format(new Date(invoice.due_date + "T12:00:00+07:00"))
    : "sesuai kesepakatan sewa";
  const body = {
    messaging_product: "whatsapp",
    recipient_type: "individual",
    to: recipient,
    type: "template",
    template: {
      name: templateName,
      language: { code: language },
      components: [{
        type: "body",
        parameters: [
          { type: "text", text: tenant.name?.trim() || "Penghuni" },
          { type: "text", text: invoice.invoice_number || invoice.billing_period },
          { type: "text", text: rupiah(Math.max(0, Number(invoice.amount_due) - Number(invoice.amount_paid))) },
          { type: "text", text: dueDate },
        ],
      }],
    },
  };
  const response = await fetch(`https://graph.facebook.com/${version}/${phoneId}/messages`, {
    method: "POST",
    headers: { authorization: `Bearer ${token}`, "content-type": "application/json" },
    body: JSON.stringify(body),
  });
  const result = await response.json().catch(() => ({}));
  if (!response.ok) {
    console.error("WhatsApp Cloud API rejected message", response.status, JSON.stringify(result).slice(0, 1000));
    throw new Error("WhatsApp gagal mengirim pesan. Periksa template dan konfigurasi WhatsApp Business.");
  }
  return result?.messages?.[0]?.id ?? "";
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return corsPreflightResponse();
  if (req.method !== "POST") return errorResponse("Method not allowed.", 405, "METHOD_NOT_ALLOWED");

  try {
    const body = await req.json().catch(() => ({}));
    const action = body.action;
    const admin = createAdminClient();

    if (action === "run-reminders") {
      const secret = Deno.env.get("WHATSAPP_REMINDER_CRON_SECRET");
      const authorization = req.headers.get("authorization") ?? "";
      if (!secret || authorization !== `Bearer ${secret}`) {
        return errorResponse("Unauthorized scheduler.", 401, "UNAUTHORIZED");
      }

      const now = new Date().toISOString();
      const { data: due, error } = await admin.from("whatsapp_billing_outbox")
        .select("id,payment_id,tenant_id,property_id,owner_id,reminder_count")
        .eq("status", "sent").lte("next_reminder_at", now).lt("reminder_count", 3)
        .order("next_reminder_at", { ascending: true }).limit(50);
      if (error) throw error;

      let sent = 0;
      for (const row of due ?? []) {
        const { data: invoice } = await admin.from("payments")
          .select("id,tenant_id,property_id,billing_period,invoice_number,due_date,amount_due,amount_paid,status")
          .eq("id", row.payment_id).maybeSingle();
        if (!invoice || ["paid", "cancelled", "expired"].includes(invoice.status) ||
            Number(invoice.amount_due) <= Number(invoice.amount_paid)) {
          await admin.from("whatsapp_billing_outbox").update({ status: invoice?.status === "paid" ? "paid" : "stopped", next_reminder_at: null, updated_at: now }).eq("id", row.id);
          continue;
        }
        const { data: tenant } = await admin.from("tenants")
          .select("id,name,phone,profile_id,whatsapp_billing_opt_in")
          .eq("id", row.tenant_id).maybeSingle();
        if (!tenant?.whatsapp_billing_opt_in || !tenant.phone) {
          await admin.from("whatsapp_billing_outbox").update({ status: "stopped", next_reminder_at: null, updated_at: now, last_error: "Tenant consent or phone number missing." }).eq("id", row.id);
          continue;
        }
        try {
          const messageId = await sendTemplate(tenant.phone, invoice as Invoice, tenant as Tenant);
          const count = Number(row.reminder_count) + 1;
          await admin.from("whatsapp_billing_outbox").update({
            reminder_count: count, last_sent_at: now, last_message_id: messageId,
            next_reminder_at: count >= 3 ? null : new Date(Date.now() + 3 * 86400000).toISOString(),
            updated_at: now, last_error: null,
          }).eq("id", row.id).eq("status", "sent");
          sent++;
        } catch (err) {
          await admin.from("whatsapp_billing_outbox").update({ last_error: err instanceof Error ? err.message : "Send failed", updated_at: now }).eq("id", row.id);
        }
      }
      return jsonResponse({ processed: due?.length ?? 0, sent });
    }

    if (action !== "approve-invoice") return errorResponse("Unknown action.", 400, "INVALID_ACTION");
    const user = await getAuthenticatedUser(req);
    if (!user) return errorResponse("Unauthorized.", 401, "UNAUTHORIZED");
    const invoiceId = typeof body.invoice_id === "string" ? body.invoice_id : "";
    if (!invoiceId) return errorResponse("invoice_id is required.");

    const { data: invoice, error: invoiceError } = await admin.from("payments")
      .select("id,tenant_id,property_id,billing_period,invoice_number,due_date,amount_due,amount_paid,status")
      .eq("id", invoiceId).maybeSingle();
    if (invoiceError || !invoice) return errorResponse("Tagihan tidak ditemukan.", 404, "NOT_FOUND");
    if (["paid", "cancelled", "expired"].includes(invoice.status) ||
        Number(invoice.amount_due) <= Number(invoice.amount_paid)) {
      return errorResponse("Tagihan tidak aktif atau sudah lunas.", 409, "INVOICE_CLOSED");
    }

    const { data: property } = await admin.from("properties").select("owner_id").eq("id", invoice.property_id).maybeSingle();
    if (!property || property.owner_id !== user.id) return errorResponse("Forbidden.", 403, "FORBIDDEN");

    const { data: tenant } = await admin.from("tenants")
      .select("id,name,phone,profile_id,whatsapp_billing_opt_in")
      .eq("id", invoice.tenant_id).maybeSingle();
    if (!tenant?.whatsapp_billing_opt_in) return errorResponse("Penyewa belum memberikan persetujuan menerima pengingat WhatsApp.", 409, "CONSENT_REQUIRED");
    if (!tenant.phone) return errorResponse("Nomor WhatsApp penyewa belum tersedia.", 409, "PHONE_REQUIRED");

    const { data: existing, error: existingError } = await admin.from("whatsapp_billing_outbox")
      .select("id,status").eq("payment_id", invoiceId).maybeSingle();
    if (existingError) throw existingError;
    if (existing && existing.status !== "failed") return errorResponse("Penagihan untuk tagihan ini sudah diproses.", 409, "ALREADY_QUEUED");

    const timestamp = new Date().toISOString();
    let queueId: string;
    if (existing) {
      const { data: updated, error: updateError } = await admin.from("whatsapp_billing_outbox").update({
        status: "sending", approved_by: user.id, approved_at: timestamp, last_error: null, updated_at: timestamp,
      }).eq("id", existing.id).eq("status", "failed").select("id").single();
      if (updateError || !updated) return errorResponse("Tidak dapat memulai ulang penagihan.", 409, "QUEUE_CONFLICT");
      queueId = updated.id;
    } else {
      const { data: inserted, error: insertError } = await admin.from("whatsapp_billing_outbox").insert({
        payment_id: invoiceId, tenant_id: invoice.tenant_id, property_id: invoice.property_id,
        owner_id: user.id, status: "sending", approved_by: user.id, approved_at: timestamp,
      }).select("id").single();
      if (insertError || !inserted) throw insertError ?? new Error("Queue insert failed");
      queueId = inserted.id;
    }

    try {
      const messageId = await sendTemplate(tenant.phone, invoice as Invoice, tenant as Tenant);
      const { error: finishError } = await admin.from("whatsapp_billing_outbox").update({
        status: "sent", first_sent_at: timestamp, last_sent_at: timestamp, next_reminder_at: new Date(Date.now() + 3 * 86400000).toISOString(),
        last_message_id: messageId, last_error: null, updated_at: new Date().toISOString(),
      }).eq("id", queueId).eq("status", "sending");
      if (finishError) throw finishError;
      return jsonResponse({ status: "sent", queue_id: queueId, message_id: messageId }, 200);
    } catch (err) {
      await admin.from("whatsapp_billing_outbox").update({
        status: "failed", last_error: err instanceof Error ? err.message : "Send failed", updated_at: new Date().toISOString(),
      }).eq("id", queueId);
      throw err;
    }
  } catch (err) {
    console.error("whatsapp-billing error:", err);
    return errorResponse(err instanceof Error ? err.message : "Internal server error.", 500, "INTERNAL_ERROR");
  }
});
