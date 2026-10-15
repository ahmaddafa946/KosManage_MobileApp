import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createAdminClient, getAuthenticatedUser } from "../_shared/supabase-admin.ts";
import { corsPreflightResponse, errorResponse, jsonResponse } from "../_shared/response-helper.ts";
import {
  MAX_REMINDERS,
  nextReminderAt,
  normalizePhone,
  outstandingAmount,
  retryAt,
} from "./reminder-logic.ts";

type Invoice = {
  id: string; tenant_id: string; property_id: string; billing_period: string;
  invoice_number: string | null; due_date: string | null; amount_due: number;
  amount_paid: number; status: string;
};
type Tenant = {
  id: string; name: string | null; phone: string | null; profile_id: string | null;
  property_id?: string;
  whatsapp_billing_opt_in: boolean;
};

function rupiah(value: number): string {
  return new Intl.NumberFormat("id-ID", { style: "currency", currency: "IDR", maximumFractionDigits: 0 }).format(value);
}

async function sendTemplate(to: string, invoice: Invoice, tenant: Tenant): Promise<string> {
  const token = Deno.env.get("WHATSAPP_ACCESS_TOKEN");
  const phoneId = Deno.env.get("WHATSAPP_PHONE_NUMBER_ID");
  const version = Deno.env.get("WHATSAPP_API_VERSION");
  const templateName = Deno.env.get("WHATSAPP_BILLING_TEMPLATE_NAME");
  const language = Deno.env.get("WHATSAPP_TEMPLATE_LANGUAGE") ?? "id";
  if (!token || !phoneId || !version || !/^v\\d+\\.\\d+$/.test(version) || !templateName) {
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
          { type: "text", text: rupiah(outstandingAmount(invoice.amount_due, invoice.amount_paid)) },
          { type: "text", text: dueDate },
        ],
      }],
    },
  };
  const response = await fetch(`https://graph.facebook.com/${version}/${phoneId}/messages`, {
    method: "POST",
    headers: { authorization: `Bearer ${token}`, "content-type": "application/json" },
    signal: AbortSignal.timeout(15_000),
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
      const staleCutoff = new Date(Date.now() - 15 * 60 * 1000).toISOString();

      // Recover claims left behind by a crashed reminder invocation. Initial approvals
      // have first_sent_at = NULL and are intentionally not recovered by this path.
      const { error: recoverError } = await admin.from("whatsapp_billing_outbox")
        .update({
          status: "sent",
          next_reminder_at: now,
          updated_at: now,
          last_error: "Recovered an interrupted reminder attempt.",
        })
        .eq("status", "sending")
        .not("first_sent_at", "is", null)
        .lt("updated_at", staleCutoff);
      if (recoverError) throw recoverError;

      const { data: due, error } = await admin.from("whatsapp_billing_outbox")
        .select("id,payment_id,tenant_id,property_id,owner_id,reminder_count")
        .eq("status", "sent").lte("next_reminder_at", now).lt("reminder_count", MAX_REMINDERS)
        .order("next_reminder_at", { ascending: true }).limit(50);
      if (error) throw error;

      let sent = 0;
      for (const row of due ?? []) {
        // Compare-and-set claim: only one concurrent scheduler can move a due row
        // from sent to sending. A second worker sees no returned row and skips it.
        const claimTime = new Date().toISOString();
        const { data: claimed, error: claimError } = await admin.from("whatsapp_billing_outbox")
          .update({ status: "sending", updated_at: claimTime })
          .eq("id", row.id)
          .eq("status", "sent")
          .eq("reminder_count", row.reminder_count)
          .lte("next_reminder_at", now)
          .select("id")
          .maybeSingle();
        if (claimError) {
          console.error("Could not claim WhatsApp reminder", claimError);
          continue;
        }
        if (!claimed) continue;

        const scheduleRetry = async (message: string) => {
          const retryTime = new Date();
          await admin.from("whatsapp_billing_outbox").update({
            status: "sent",
            next_reminder_at: retryAt(retryTime),
            updated_at: retryTime.toISOString(),
            last_error: message,
          }).eq("id", row.id).eq("status", "sending");
        };

        const { data: invoice, error: invoiceError } = await admin.from("payments")
          .select("id,tenant_id,property_id,billing_period,invoice_number,due_date,amount_due,amount_paid,status")
          .eq("id", row.payment_id).maybeSingle();
        if (invoiceError) {
          await scheduleRetry("Could not load invoice; retry scheduled.");
          continue;
        }
        if (!invoice || ["paid", "cancelled", "expired"].includes(invoice.status) ||
            outstandingAmount(Number(invoice.amount_due), Number(invoice.amount_paid)) <= 0) {
          await admin.from("whatsapp_billing_outbox").update({
            status: invoice?.status === "paid" ? "paid" : "stopped",
            next_reminder_at: null,
            updated_at: new Date().toISOString(),
          }).eq("id", row.id).eq("status", "sending");
          continue;
        }

        const { data: tenant, error: tenantError } = await admin.from("tenants")
          .select("id,name,phone,profile_id,property_id,whatsapp_billing_opt_in")
          .eq("id", row.tenant_id).maybeSingle();
        if (tenantError) {
          await scheduleRetry("Could not load tenant; retry scheduled.");
          continue;
        }
        if (!tenant?.whatsapp_billing_opt_in || !tenant.phone || tenant.property_id !== invoice.property_id) {
          await admin.from("whatsapp_billing_outbox").update({
            status: "stopped",
            next_reminder_at: null,
            updated_at: new Date().toISOString(),
            last_error: "Tenant consent, phone number, or property link is invalid.",
          }).eq("id", row.id).eq("status", "sending");
          continue;
        }

        try {
          const messageId = await sendTemplate(tenant.phone, invoice as Invoice, tenant as Tenant);
          const reminderCount = Number(row.reminder_count) + 1;
          const sentAt = new Date();
          const { error: finishError } = await admin.from("whatsapp_billing_outbox").update({
            status: "sent",
            reminder_count: reminderCount,
            last_sent_at: sentAt.toISOString(),
            last_message_id: messageId,
            next_reminder_at: nextReminderAt(sentAt, reminderCount),
            updated_at: sentAt.toISOString(),
            last_error: null,
          }).eq("id", row.id).eq("status", "sending");
          if (finishError) console.error("Reminder was sent but outbox update failed", finishError);
          sent++;
        } catch (err) {
          await scheduleRetry(err instanceof Error ? err.message : "WhatsApp send failed; retry scheduled.");
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
        outstandingAmount(Number(invoice.amount_due), Number(invoice.amount_paid)) <= 0) {
      return errorResponse("Tagihan tidak aktif atau sudah lunas.", 409, "INVOICE_CLOSED");
    }

    const { data: property } = await admin.from("properties").select("owner_id").eq("id", invoice.property_id).maybeSingle();
    if (!property || property.owner_id !== user.id) return errorResponse("Forbidden.", 403, "FORBIDDEN");

    const { data: tenant, error: tenantError } = await admin.from("tenants")
      .select("id,name,phone,profile_id,property_id,whatsapp_billing_opt_in")
      .eq("id", invoice.tenant_id).maybeSingle();
    if (tenantError || !tenant || tenant.property_id !== invoice.property_id) {
      return errorResponse("Data penyewa dan properti tidak cocok.", 409, "TENANT_PROPERTY_MISMATCH");
    }
    if (!tenant.whatsapp_billing_opt_in) return errorResponse("Penyewa belum memberikan persetujuan menerima pengingat WhatsApp.", 409, "CONSENT_REQUIRED");
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

    // Re-check consent and tenant/property relationship immediately before calling Meta.
    const { data: consentCheck, error: consentError } = await admin.from("tenants")
      .select("whatsapp_billing_opt_in,phone,property_id")
      .eq("id", invoice.tenant_id).maybeSingle();
    if (consentError || !consentCheck?.whatsapp_billing_opt_in || !consentCheck.phone ||
        consentCheck.property_id !== invoice.property_id) {
      await admin.from("whatsapp_billing_outbox").update({
        status: "stopped", next_reminder_at: null, last_error: "Consent or tenant details changed before send.",
        updated_at: new Date().toISOString(),
      }).eq("id", queueId).eq("status", "sending");
      return errorResponse("Persetujuan atau data WhatsApp penyewa berubah. Pesan tidak dikirim.", 409, "CONSENT_CHANGED");
    }

    try {
      const messageId = await sendTemplate(consentCheck.phone, invoice as Invoice, { ...tenant, phone: consentCheck.phone } as Tenant);
      const sentAt = new Date();
      const { error: finishError } = await admin.from("whatsapp_billing_outbox").update({
        status: "sent", first_sent_at: sentAt.toISOString(), last_sent_at: sentAt.toISOString(),
        next_reminder_at: nextReminderAt(sentAt, 0), last_message_id: messageId, last_error: null,
        updated_at: sentAt.toISOString(),
      }).eq("id", queueId).eq("status", "sending");
      if (finishError) throw finishError;
      return jsonResponse({ status: "sent", queue_id: queueId, message_id: messageId }, 200);
    } catch (err) {
      await admin.from("whatsapp_billing_outbox").update({
        status: "failed", last_error: err instanceof Error ? err.message : "Send failed", updated_at: new Date().toISOString(),
      }).eq("id", queueId).eq("status", "sending");
      throw err;
    }
  } catch (err) {
    console.error("whatsapp-billing error:", err);
    return errorResponse(err instanceof Error ? err.message : "Internal server error.", 500, "INTERNAL_ERROR");
  }
});
