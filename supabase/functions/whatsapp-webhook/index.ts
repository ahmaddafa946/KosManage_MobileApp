import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createAdminClient } from "../_shared/supabase-admin.ts";
import {
  corsPreflightResponse,
  errorResponse,
  jsonResponse,
} from "../_shared/response-helper.ts";
import {
  constantTimeEqual,
  isUuid,
  normalizePhone,
  parseIncomingAction,
  verifyMetaSignature,
} from "./webhook-logic.ts";
import { getPaymentGateway } from "../_shared/midtrans-provider.ts";

type Tenant = {
  id: string;
  name: string | null;
  phone: string | null;
  email: string | null;
  profile_id: string | null;
  property_id: string;
  whatsapp_billing_opt_in: boolean;
};
type Invoice = {
  id: string;
  tenant_id: string;
  property_id: string;
  room_id: string | null;
  billing_period: string;
  invoice_number: string | null;
  due_date: string | null;
  amount_due: number;
  amount_paid: number;
  status: string;
  is_renewal?: boolean;
};
type IncomingMessage = {
  id?: string;
  from?: string;
  type?: string;
  text?: { body?: string };
  button?: { payload?: string; text?: string };
  interactive?: {
    button_reply?: { id?: string; title?: string };
    list_reply?: { id?: string; title?: string };
  };
};
type Transaction = {
  id: string;
  order_id: string;
  payment_method: string;
  status: string;
  gross_amount: number;
  qr_url?: string | null;
  qr_string?: string | null;
  va_number?: string | null;
  bank?: string | null;
  expires_at?: string | null;
};
const ACTIVE_TRANSACTION_STATUSES = ["created", "pending", "waiting_confirmation"];
const BANK_LABELS: Record<string, string> = {
  bca: "BCA",
  bni: "BNI",
  bri: "BRI",
  mandiri: "Mandiri",
  permata: "Permata",
};

function formatRupiah(value: number): string {
  return new Intl.NumberFormat("id-ID", {
    style: "currency",
    currency: "IDR",
    maximumFractionDigits: 0,
  }).format(Math.max(0, value));
}

function outstanding(invoice: Invoice): number {
  return Math.max(0, Number(invoice.amount_due) - Number(invoice.amount_paid));
}

function formatDueDate(value: string | null): string {
  if (!value) return "sesuai kesepakatan sewa";
  const date = new Date(value + "T12:00:00+07:00");
  return new Intl.DateTimeFormat("id-ID", {
    dateStyle: "long",
    timeZone: "Asia/Jakarta",
  }).format(date);
}

function formatExpiry(value: string | null | undefined): string {
  if (!value) return "lihat aplikasi KosManage";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "lihat aplikasi KosManage";
  return new Intl.DateTimeFormat("id-ID", {
    dateStyle: "long",
    timeStyle: "short",
    timeZone: "Asia/Jakarta",
  }).format(date) + " WIB";
}

function isInvoiceOpen(invoice: Invoice): boolean {
  return !["paid", "cancelled", "expired"].includes(invoice.status) &&
    outstanding(invoice) > 0;
}

function getConfig() {
  const token = Deno.env.get("WHATSAPP_ACCESS_TOKEN");
  const phoneId = Deno.env.get("WHATSAPP_PHONE_NUMBER_ID");
  const version = Deno.env.get("WHATSAPP_API_VERSION");
  if (!token || !phoneId || !version || !/^v\d+\.\d+$/.test(version)) {
    throw new Error("WhatsApp Cloud API is not configured.");
  }
  return { token, phoneId, version };
}

async function sendMetaMessage(to: string, message: Record<string, unknown>) {
  const { token, phoneId, version } = getConfig();
  const recipient = normalizePhone(to);
  if (!recipient) throw new Error("Invalid WhatsApp recipient number.");
  const response = await fetch(
    `https://graph.facebook.com/${version}/${phoneId}/messages`,
    {
      method: "POST",
      headers: {
        authorization: `Bearer ${token}`,
        "content-type": "application/json",
      },
      signal: AbortSignal.timeout(15_000),
      body: JSON.stringify({
        messaging_product: "whatsapp",
        recipient_type: "individual",
        to: recipient,
        ...message,
      }),
    },
  );
  const result = await response.json().catch(() => ({})) as Record<string, unknown>;
  if (!response.ok) {
    console.error("WhatsApp webhook reply rejected", response.status);
    throw new Error("WhatsApp gagal mengirim balasan. Silakan coba kembali.");
  }
  return result;
}

async function sendText(to: string, text: string, replyTo?: string) {
  return await sendMetaMessage(to, {
    type: "text",
    text: { preview_url: false, body: text },
    ...(replyTo ? { context: { message_id: replyTo } } : {}),
  });
}

async function sendButtons(
  to: string,
  body: string,
  buttons: Array<{ id: string; title: string }>,
  replyTo?: string,
) {
  return await sendMetaMessage(to, {
    type: "interactive",
    interactive: {
      type: "button",
      body: { text: body },
      action: {
        buttons: buttons.slice(0, 3).map((button) => ({
          type: "reply",
          reply: { id: button.id, title: button.title.slice(0, 20) },
        })),
      },
    },
    ...(replyTo ? { context: { message_id: replyTo } } : {}),
  });
}

async function sendList(
  to: string,
  body: string,
  button: string,
  rows: Array<{ id: string; title: string; description: string }>,
  sectionTitle: string,
  replyTo?: string,
) {
  return await sendMetaMessage(to, {
    type: "interactive",
    interactive: {
      type: "list",
      body: { text: body },
      action: {
        button: button.slice(0, 20),
        sections: [{
          title: sectionTitle.slice(0, 24),
          rows: rows.slice(0, 10).map((row) => ({
            id: row.id,
            title: row.title.slice(0, 24),
            description: row.description.slice(0, 72),
          })),
        }],
      },
    },
    ...(replyTo ? { context: { message_id: replyTo } } : {}),
  });
}

async function sendQrImage(to: string, url: string, caption: string, replyTo?: string) {
  let parsed: URL;
  try {
    parsed = new URL(url);
  } catch {
    throw new Error("Midtrans returned an invalid QR image URL.");
  }
  if (parsed.protocol !== "https:") {
    throw new Error("Midtrans returned an unsupported QR image URL.");
  }
  return await sendMetaMessage(to, {
    type: "image",
    image: { link: parsed.toString(), caption },
    ...(replyTo ? { context: { message_id: replyTo } } : {}),
  });
}

async function findTenantByPhone(admin: ReturnType<typeof createAdminClient>, phone: string) {
  const { data, error } = await admin.rpc("find_tenant_by_whatsapp_phone", {
    p_phone: phone,
  });
  if (error) throw error;
  if (!Array.isArray(data) || data.length !== 1) return null;
  return data[0] as Tenant;
}

async function markConsentOut(admin: ReturnType<typeof createAdminClient>, tenant: Tenant) {
  const timestamp = new Date().toISOString();
  const { error } = await admin.from("tenants").update({
    whatsapp_billing_opt_in: false,
    whatsapp_billing_opt_out_at: timestamp,
    updated_at: timestamp,
  }).eq("id", tenant.id);
  if (error) throw error;
  const { error: stopError } = await admin.from("whatsapp_billing_outbox").update({
    status: "stopped",
    next_reminder_at: null,
    updated_at: timestamp,
    last_error: "Tenant opted out via WhatsApp.",
  }).eq("tenant_id", tenant.id).in("status", [
    "pending_approval",
    "sending",
    "sent",
    "failed",
  ]);
  if (stopError) throw stopError;
}

async function loadInvoice(
  admin: ReturnType<typeof createAdminClient>,
  tenant: Tenant,
  invoiceId: string,
): Promise<Invoice | null> {
  if (!isUuid(invoiceId)) return null;
  const { data, error } = await admin.from("payments").select(
    "id,tenant_id,property_id,room_id,billing_period,invoice_number,due_date,amount_due,amount_paid,status,is_renewal",
  ).eq("id", invoiceId).eq("tenant_id", tenant.id).maybeSingle();
  if (error) throw error;
  if (!data) return null;
  const invoice = data as Invoice;
  if (invoice.property_id !== tenant.property_id || !isInvoiceOpen(invoice)) return null;
  return invoice;
}

async function showOpenInvoices(
  admin: ReturnType<typeof createAdminClient>,
  tenant: Tenant,
  phone: string,
  replyTo?: string,
) {
  const { data, error } = await admin.from("payments").select(
    "id,tenant_id,property_id,room_id,billing_period,invoice_number,due_date,amount_due,amount_paid,status,is_renewal",
  ).eq("tenant_id", tenant.id)
    .in("status", ["unpaid", "partial", "overdue"])
    .order("due_date", { ascending: true })
    .limit(20);
  if (error) throw error;
  const invoices = (data ?? []).map((row) => row as Invoice)
    .filter((invoice) => invoice.property_id === tenant.property_id && isInvoiceOpen(invoice))
    .slice(0, 10);

  if (invoices.length === 0) {
    await sendText(phone, "Saat ini tidak ada tagihan sewa aktif yang perlu dibayar. Jika menurut Anda data ini tidak sesuai, silakan periksa aplikasi KosManage.", replyTo);
    return;
  }
  const rows = invoices.map((invoice) => ({
    id: `invoice:${invoice.id}`,
    title: (invoice.invoice_number || invoice.billing_period).slice(0, 24),
    description: `Sisa ${formatRupiah(outstanding(invoice))} • Jatuh tempo ${formatDueDate(invoice.due_date)}`,
  }));
  await sendList(
    phone,
    "Berikut tagihan sewa Anda yang masih memiliki sisa pembayaran. Pilih tagihan untuk melihat metode pembayaran.",
    "Pilih tagihan",
    rows,
    "Tagihan aktif",
    replyTo,
  );
}

async function showInvoicePaymentOptions(
  admin: ReturnType<typeof createAdminClient>,
  tenant: Tenant,
  phone: string,
  invoiceId: string,
  replyTo?: string,
) {
  const invoice = await loadInvoice(admin, tenant, invoiceId);
  if (!invoice) {
    await sendText(phone, "Tagihan tidak ditemukan, sudah lunas, atau tidak aktif. Kirim TAGIHAN untuk melihat daftar terbaru.", replyTo);
    return;
  }
  await sendButtons(
    phone,
    `Tagihan ${invoice.invoice_number || invoice.billing_period}\nSisa pembayaran: ${formatRupiah(outstanding(invoice))}\nJatuh tempo: ${formatDueDate(invoice.due_date)}\n\nPilih metode pembayaran:`,
    [
      { id: `pay:qris:${invoice.id}`, title: "QRIS" },
      { id: `pay:transfer:${invoice.id}`, title: "Transfer bank" },
      { id: `pay:cash:${invoice.id}`, title: "Tunai" },
    ],
    replyTo,
  );
}

async function showBankOptions(
  admin: ReturnType<typeof createAdminClient>,
  tenant: Tenant,
  phone: string,
  invoiceId: string,
  replyTo?: string,
) {
  const invoice = await loadInvoice(admin, tenant, invoiceId);
  if (!invoice) {
    await sendText(phone, "Tagihan sudah tidak aktif atau tidak ditemukan. Kirim TAGIHAN untuk melihat daftar terbaru.", replyTo);
    return;
  }
  await sendList(
    phone,
    `Pilih bank untuk tagihan ${invoice.invoice_number || invoice.billing_period} sebesar ${formatRupiah(outstanding(invoice))}.`,
    "Pilih bank",
    Object.entries(BANK_LABELS).map(([bank, label]) => ({
      id: `bank:${bank}:${invoice.id}`,
      title: label,
      description: "Transfer bank otomatis",
    })),
    "Bank tersedia",
    replyTo,
  );
}

async function notifyExistingTransaction(phone: string, tx: Transaction, invoice: Invoice, replyTo?: string) {
  if (tx.payment_method === "qris" && tx.qr_url) {
    const caption = `QRIS aktif untuk tagihan ${invoice.invoice_number || invoice.billing_period}. Nominal: ${formatRupiah(Number(tx.gross_amount))}. Setelah pembayaran, status akan diperbarui melalui payment gateway.`;
    try {
      await sendQrImage(phone, tx.qr_url, caption, replyTo);
    } catch {
      await sendText(phone, `Masih ada transaksi QRIS aktif (${tx.order_id}) sebesar ${formatRupiah(Number(tx.gross_amount))}. Buka detail pembayaran di aplikasi KosManage dan jangan membuat transaksi baru.`, replyTo);
    }
    return;
  }
  if (tx.payment_method === "bank_transfer" && tx.va_number) {
    await sendText(phone, `Masih ada transaksi transfer aktif untuk tagihan ${invoice.invoice_number || invoice.billing_period}. Bank: ${BANK_LABELS[tx.bank ?? ""] ?? tx.bank ?? "lihat aplikasi"}. Nomor VA: ${tx.va_number}. Nominal: ${formatRupiah(Number(tx.gross_amount))}. Silakan selesaikan transaksi tersebut terlebih dahulu.`, replyTo);
    return;
  }
  if (tx.payment_method === "cash" || tx.status === "waiting_confirmation") {
    await sendText(phone, `Permintaan pembayaran tunai (${tx.order_id}) masih menunggu konfirmasi pemilik kos. Status belum dianggap lunas sampai pemilik mengonfirmasi di KosManage.`, replyTo);
    return;
  }
  await sendText(phone, `Tagihan ini sudah memiliki transaksi aktif (${tx.order_id}). Untuk mencegah pembayaran ganda, selesaikan atau periksa transaksi tersebut di aplikasi KosManage terlebih dahulu.`, replyTo);
}

async function findActiveTransaction(
  admin: ReturnType<typeof createAdminClient>,
  invoiceId: string,
): Promise<Transaction | null> {
  const { data, error } = await admin.from("payment_transactions").select(
    "id,order_id,payment_method,status,gross_amount,qr_url,qr_string,va_number,bank,expires_at",
  ).eq("payment_id", invoiceId).in("status", ACTIVE_TRANSACTION_STATUSES)
    .limit(1).maybeSingle();
  if (error) throw error;
  return data as Transaction | null;
}

async function createCashRequest(
  admin: ReturnType<typeof createAdminClient>,
  tenant: Tenant,
  invoice: Invoice,
  phone: string,
  replyTo?: string,
) {
  const netDue = outstanding(invoice);
  const orderId = `KMC-${invoice.id.substring(0, 8).toUpperCase()}-${Date.now().toString(36).toUpperCase()}`;
  const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60_000).toISOString();
  const { data: inserted, error: insertError } = await admin.from("payment_transactions").insert({
    payment_id: invoice.id,
    tenant_id: tenant.id,
    order_id: orderId,
    payment_method: "cash",
    payment_provider: "manual",
    gross_amount: netDue,
    status: "waiting_confirmation",
    expires_at: expiresAt,
  }).select("id,order_id,gross_amount,status").single();
  if (insertError) {
    if (insertError.code === "23505") {
      const existing = await findActiveTransaction(admin, invoice.id);
      if (existing) await notifyExistingTransaction(phone, existing, invoice, replyTo);
      else await sendText(phone, "Tagihan sudah memiliki transaksi aktif. Periksa aplikasi KosManage sebelum mencoba lagi.", replyTo);
      return;
    }
    throw insertError;
  }

  const timestamp = new Date().toISOString();
  const { error: paymentMethodError } = await admin.from("payments")
    .update({ payment_method: "cash", updated_at: timestamp }).eq("id", invoice.id);
  if (paymentMethodError) throw paymentMethodError;

  const { data: property, error: propertyError } = await admin.from("properties")
    .select("owner_id").eq("id", invoice.property_id).maybeSingle();
  if (propertyError) throw propertyError;
  if (property?.owner_id) {
    const { error: notificationError } = await admin.from("notifications").insert({
      profile_id: property.owner_id,
      title: "Konfirmasi Pembayaran Tunai",
      message: `Penghuni ${tenant.name ?? "Penghuni"} memilih pembayaran tunai untuk periode ${invoice.billing_period}. Mohon konfirmasi saat dana diterima.`,
      type: "cash_confirmation_required",
      data: { payment_id: invoice.id, transaction_id: inserted.id, tenant_name: tenant.name },
    });
    if (notificationError) throw notificationError;
  }

  await sendText(
    phone,
    `Permintaan pembayaran tunai tercatat dengan nomor ${inserted.order_id}. Nominal: ${formatRupiah(Number(inserted.gross_amount))}. Serahkan pembayaran kepada pemilik kos dan tunggu konfirmasi di aplikasi KosManage. Pesan ini tidak berarti pembayaran sudah lunas.`,
    replyTo,
  );
}

async function createGatewayRequest(
  admin: ReturnType<typeof createAdminClient>,
  tenant: Tenant,
  invoice: Invoice,
  method: "qris" | "bank_transfer",
  phone: string,
  bank?: string,
  replyTo?: string,
) {
  const netDue = outstanding(invoice);
  const existing = await findActiveTransaction(admin, invoice.id);
  if (existing) {
    await notifyExistingTransaction(phone, existing, invoice, replyTo);
    return;
  }

  let roomNumber = "Kos";
  if (invoice.room_id) {
    const { data: room, error: roomError } = await admin.from("rooms")
      .select("room_number").eq("id", invoice.room_id).maybeSingle();
    if (roomError) throw roomError;
    if (room) roomNumber = `Kamar ${room.room_number}`;
  }

  const orderId = `KM-${invoice.id.substring(0, 8).toUpperCase()}-${Date.now().toString(36).toUpperCase()}`;
  const { data: reservation, error: reserveError } = await admin.from("payment_transactions").insert({
    payment_id: invoice.id,
    tenant_id: tenant.id,
    order_id: orderId,
    payment_method: method,
    payment_provider: "midtrans",
    gross_amount: netDue,
    status: "created",
    expires_at: new Date(Date.now() + (method === "qris" ? 15 : 24 * 60) * 60_000).toISOString(),
  }).select("id").single();

  if (reserveError) {
    if (reserveError.code === "23505") {
      const active = await findActiveTransaction(admin, invoice.id);
      if (active) await notifyExistingTransaction(phone, active, invoice, replyTo);
      else await sendText(phone, "Tagihan sudah memiliki transaksi aktif. Periksa aplikasi KosManage sebelum mencoba lagi.", replyTo);
      return;
    }
    throw reserveError;
  }

  const gateway = getPaymentGateway();
  let result: Record<string, unknown>;
  try {
    const params = {
      orderId,
      grossAmount: netDue,
      customerDetails: {
        firstName: tenant.name ?? "Tenant",
        email: tenant.email ?? "tenant@kosmanage.app",
        phone: tenant.phone,
      },
      itemDetails: [{
        id: invoice.room_id ?? invoice.id,
        price: netDue,
        quantity: 1,
        name: `Sewa ${roomNumber} Periode ${invoice.billing_period}`,
      }],
    };

    if (method === "qris") {
      const qr = await gateway.createQrPayment(params);
      result = {
        status: "pending",
        gateway_reference: qr.transactionId,
        qr_string: qr.qrString,
        qr_url: qr.qrImageUrl ?? null,
        expires_at: qr.expiresAt,
        payload_response: qr.rawResponse,
      };
    } else {
      if (!bank || !BANK_LABELS[bank]) throw new Error("Bank transfer is not supported.");
      const transfer = await gateway.createBankTransfer(params, bank);
      result = {
        status: "pending",
        bank: transfer.bank,
        va_number: transfer.vaNumber,
        gateway_reference: transfer.transactionId,
        expires_at: transfer.expiresAt,
        payload_response: transfer.rawResponse,
      };
    }
  } catch (err) {
    const message = err instanceof Error ? err.message : "Gateway request failed.";
    // Definite provider rejections can release the reservation. For an unknown
    // network outcome, keep status=created so a retry cannot double-charge.
    if (message.startsWith("Midtrans charge failed:")) {
      await admin.from("payment_transactions").update({
        status: "failed",
        updated_at: new Date().toISOString(),
      }).eq("id", reservation.id).eq("status", "created");
      await sendText(phone, "Gateway menolak pembuatan transaksi. Tidak ada status pembayaran yang diubah. Silakan coba kembali dari aplikasi KosManage atau hubungi pemilik kos.", replyTo);
    } else {
      await sendText(phone, `Permintaan pembayaran (${orderId}) sedang diverifikasi karena koneksi ke gateway terputus. Jangan membuat transaksi baru dulu; periksa aplikasi KosManage atau hubungi pemilik kos.`, replyTo);
    }
    return;
  }

  const { error: transactionUpdateError } = await admin.from("payment_transactions").update({
    ...result,
    updated_at: new Date().toISOString(),
  }).eq("id", reservation.id).eq("status", "created");
  if (transactionUpdateError) {
    console.error("Could not persist gateway result; reservation retained for reconciliation.", transactionUpdateError);
    await sendText(phone, `Gateway sudah mengembalikan transaksi ${orderId}, tetapi detail belum tersimpan sepenuhnya. Jangan membayar ulang; periksa aplikasi KosManage atau hubungi pemilik kos.`, replyTo);
    return;
  }

  const legacyMethod = method === "qris" ? "ewallet" : "transfer";
  const { error: methodError } = await admin.from("payments")
    .update({ payment_method: legacyMethod, updated_at: new Date().toISOString() })
    .eq("id", invoice.id);
  if (methodError) {
    console.error("Could not update invoice payment method after gateway creation.", methodError);
  }

  if (method === "qris") {
    const qrUrl = typeof result.qr_url === "string" ? result.qr_url : null;
    const caption = `Pembayaran QRIS untuk ${invoice.invoice_number || invoice.billing_period}. Nominal: ${formatRupiah(netDue)}. Setelah membayar, status akan diperbarui melalui Midtrans. Nomor transaksi: ${orderId}.`;
    if (qrUrl) {
      try {
        await sendQrImage(phone, qrUrl, caption, replyTo);
        return;
      } catch (err) {
        console.error("QR image send failed; sending transaction fallback.", err);
      }
    }
    await sendText(phone, `${caption}\nQR gambar tidak dapat dikirim di WhatsApp. Buka aplikasi KosManage untuk menampilkan QR dan selesaikan pembayaran di sana. Jangan gunakan QR dari sumber lain.`, replyTo);
    return;
  }

  const va = typeof result.va_number === "string" ? result.va_number : "";
  const selectedBank = typeof result.bank === "string" ? result.bank : bank ?? "";
  await sendText(
    phone,
`Instruksi transfer untuk ${invoice.invoice_number || invoice.billing_period}\nBank: ${BANK_LABELS[selectedBank] ?? selectedBank}\nNomor VA: ${va || "lihat aplikasi KosManage"}\nNominal: ${formatRupiah(netDue)}\nBerlaku sampai: ${formatExpiry(typeof result.expires_at === "string" ? result.expires_at : null)}\n\nPembayaran diverifikasi otomatis melalui Midtrans. Jangan bagikan nomor transaksi kepada pihak yang tidak dikenal.`,
    replyTo,
  );
}

async function handleAction(
  admin: ReturnType<typeof createAdminClient>,
  tenant: Tenant,
  phone: string,
  actionValue: string,
  messageId: string,
) {
  const action = parseIncomingAction(actionValue);
  switch (action.kind) {
    case "stop":
      await markConsentOut(admin, tenant);
      await sendText(phone, "Pengingat tagihan WhatsApp telah dihentikan. Anda tetap dapat melihat dan membayar tagihan melalui aplikasi KosManage. Untuk mengaktifkan pengingat lagi, gunakan menu persetujuan di aplikasi.", messageId);
      return;
    case "invoices":
      await showOpenInvoices(admin, tenant, phone, messageId);
      return;
    case "invoice":
      await showInvoicePaymentOptions(admin, tenant, phone, action.invoiceId, messageId);
      return;
    case "pay": {
      const invoice = await loadInvoice(admin, tenant, action.invoiceId);
      if (!invoice) {
        await sendText(phone, "Tagihan tidak aktif atau tidak ditemukan. Kirim TAGIHAN untuk melihat daftar terbaru.", messageId);
        return;
      }
      if (action.method === "transfer") {
        await showBankOptions(admin, tenant, phone, invoice.id, messageId);
        return;
      }
      const existing = await findActiveTransaction(admin, invoice.id);
      if (existing) {
        await notifyExistingTransaction(phone, existing, invoice, messageId);
        return;
      }
      if (action.method === "cash") {
        await createCashRequest(admin, tenant, invoice, phone, messageId);
        return;
      }
      await createGatewayRequest(admin, tenant, invoice, "qris", phone, undefined, messageId);
      return;
    }
    case "bank": {
      const invoice = await loadInvoice(admin, tenant, action.invoiceId);
      if (!invoice) {
        await sendText(phone, "Tagihan tidak aktif atau tidak ditemukan. Kirim TAGIHAN untuk melihat daftar terbaru.", messageId);
        return;
      }
      await createGatewayRequest(admin, tenant, invoice, "bank_transfer", phone, action.bank, messageId);
      return;
    }
    case "help":
      await sendText(phone, "Halo dari KosManage!\nKirim TAGIHAN untuk melihat sisa sewa dan memilih pembayaran QRIS, transfer bank, atau tunai.\nKirim STOP untuk menghentikan pengingat WhatsApp. Perintah START tidak otomatis mengaktifkan pengingat; persetujuan dikelola dari aplikasi KosManage.", messageId);
      return;
  }
}

async function claimInboundEvent(
  admin: ReturnType<typeof createAdminClient>,
  message: IncomingMessage,
  phone: string,
) {
  if (!message.id) return null;
  const now = new Date();
  const staleCutoff = new Date(now.getTime() - 15 * 60_000).toISOString();
  const { data: inserted, error: insertError } = await admin.from("whatsapp_billing_inbound_events").insert({
    message_id: message.id,
    from_phone: phone,
    message_type: message.type ?? "unknown",
  }).select("id,status,attempt_count,processing_started_at").maybeSingle();

  let row = inserted;
  if (insertError) {
    if (insertError.code !== "23505") throw insertError;
    const { data: existing, error: existingError } = await admin.from("whatsapp_billing_inbound_events")
      .select("id,status,attempt_count,processing_started_at").eq("message_id", message.id).maybeSingle();
    if (existingError) throw existingError;
    row = existing;
  }
  if (!row) return null;

  const status = row.status as string;
  if (status === "processed" || status === "ignored") return null;
  if (status === "processing" && row.processing_started_at && row.processing_started_at >= staleCutoff) return null;
  if (!["received", "failed", "processing"].includes(status)) return null;

  let query = admin.from("whatsapp_billing_inbound_events").update({
    status: "processing",
    processing_started_at: now.toISOString(),
    attempt_count: Number(row.attempt_count ?? 0) + 1,
    updated_at: now.toISOString(),
    last_error: null,
  }).eq("id", row.id).eq("status", status);
  if (status === "processing") query = query.lt("processing_started_at", staleCutoff);
  const { data: claimed, error: claimError } = await query.select("id").maybeSingle();
  if (claimError) throw claimError;
  return claimed ? { id: claimed.id as string } : null;
}

async function handleInboundMessage(
  admin: ReturnType<typeof createAdminClient>,
  message: IncomingMessage,
) {
  const phone = normalizePhone(message.from ?? "");
  if (!phone || !message.id) return;
  const claim = await claimInboundEvent(admin, message, phone);
  if (!claim) return;

  try {
    const tenant = await findTenantByPhone(admin, phone);
    if (!tenant) {
      await admin.from("whatsapp_billing_inbound_events").update({
        status: "ignored", processing_started_at: null, processed_at: new Date().toISOString(),
        updated_at: new Date().toISOString(), last_error: null,
      }).eq("id", claim.id).eq("status", "processing");
      return;
    }
    let actionValue = "";
    if (message.type === "text") {
      actionValue = message.text?.body ?? "";
    } else if (message.type === "interactive") {
      actionValue = message.interactive?.button_reply?.id ??
        message.interactive?.list_reply?.id ?? "";
    } else if (message.type === "button") {
      actionValue = message.button?.payload ?? message.button?.text ?? "";
    } else {
      await admin.from("whatsapp_billing_inbound_events").update({
        status: "ignored", processing_started_at: null, processed_at: new Date().toISOString(),
        updated_at: new Date().toISOString(), last_error: null,
      }).eq("id", claim.id).eq("status", "processing");
      return;
    }
    await handleAction(admin, tenant, phone, actionValue, message.id);
    const timestamp = new Date().toISOString();
    const { error: finishError } = await admin.from("whatsapp_billing_inbound_events").update({
      status: "processed", processing_started_at: null, processed_at: timestamp,
      updated_at: timestamp, last_error: null,
    }).eq("id", claim.id).eq("status", "processing");
    if (finishError) throw finishError;
  } catch (err) {
    await admin.from("whatsapp_billing_inbound_events").update({
      status: "failed", processing_started_at: null, updated_at: new Date().toISOString(),
      last_error: err instanceof Error ? err.message.slice(0, 500) : "Webhook processing failed.",
    }).eq("id", claim.id).eq("status", "processing");
    throw err;
  }
}

async function handleDeliveryStatuses(admin: ReturnType<typeof createAdminClient>, statuses: unknown[]) {
  for (const value of statuses) {
    if (!value || typeof value !== "object") continue;
    const status = value as { id?: string; status?: string; timestamp?: string; errors?: Array<{ title?: string }> };
    if (!status.id || !["sent", "delivered", "read", "failed"].includes(status.status ?? "")) continue;
    const timestampNumber = Number(status.timestamp);
    const statusAt = Number.isFinite(timestampNumber) && timestampNumber > 0
      ? new Date(timestampNumber * 1000).toISOString()
      : new Date().toISOString();
    const errorTitle = status.status === "failed" ? status.errors?.[0]?.title : undefined;
    const { error } = await admin.from("whatsapp_billing_outbox").update({
      last_delivery_status: status.status,
      last_status_at: statusAt,
      ...(errorTitle ? { last_error: `WhatsApp delivery failed: ${errorTitle}`.slice(0, 500) } : {}),
      updated_at: new Date().toISOString(),
    }).eq("last_message_id", status.id);
    if (error) throw error;
  }
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return corsPreflightResponse();

  const url = new URL(req.url);
  if (req.method === "GET") {
    const verifyToken = Deno.env.get("WHATSAPP_WEBHOOK_VERIFY_TOKEN");
    const mode = url.searchParams.get("hub.mode") ?? "";
    const suppliedToken = url.searchParams.get("hub.verify_token") ?? "";
    const challenge = url.searchParams.get("hub.challenge") ?? "";
    if (!verifyToken) return errorResponse("WhatsApp webhook is not configured.", 503, "NOT_CONFIGURED");
    if (mode !== "subscribe" || !challenge || !constantTimeEqual(verifyToken, suppliedToken)) {
      return errorResponse("Webhook verification failed.", 403, "VERIFY_FAILED");
    }
    return new Response(challenge, { status: 200, headers: { "content-type": "text/plain; charset=utf-8" } });
  }

  if (req.method !== "POST") return errorResponse("Method not allowed.", 405, "METHOD_NOT_ALLOWED");

  const appSecret = Deno.env.get("WHATSAPP_APP_SECRET");
  if (!appSecret) return errorResponse("WhatsApp webhook is not configured.", 503, "NOT_CONFIGURED");
  const rawBody = await req.text();
  const signature = req.headers.get("x-hub-signature-256") ?? "";
  const isValid = await verifyMetaSignature(rawBody, signature, appSecret).catch(() => false);
  if (!isValid) return errorResponse("Invalid Meta webhook signature.", 401, "INVALID_SIGNATURE");

  try {
    const payload = JSON.parse(rawBody) as {
      entry?: Array<{ changes?: Array<{ value?: { messages?: IncomingMessage[]; statuses?: unknown[] } }> }>;
    };
    if (!Array.isArray(payload.entry)) return jsonResponse({ status: "ok" });
    const admin = createAdminClient();
    for (const entry of payload.entry) {
      for (const change of entry.changes ?? []) {
        const value = change.value;
        if (!value) continue;
        if (Array.isArray(value.statuses) && value.statuses.length > 0) {
          await handleDeliveryStatuses(admin, value.statuses);
        }
        if (Array.isArray(value.messages)) {
          for (const message of value.messages) {
            await handleInboundMessage(admin, message);
          }
        }
      }
    }
    return jsonResponse({ status: "ok" });
  } catch (err) {
    console.error("WhatsApp webhook processing failed:", err instanceof Error ? err.message : "Unknown error");
    // Non-2xx allows Meta to retry; message IDs are deduplicated in the database.
    return errorResponse("Webhook event processing failed.", 500, "WEBHOOK_PROCESSING_FAILED");
  }
});
