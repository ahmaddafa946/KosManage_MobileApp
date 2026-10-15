export type IncomingAction =
  | { kind: "invoices" }
  | { kind: "stop" }
  | { kind: "help" }
  | { kind: "invoice"; invoiceId: string }
  | { kind: "pay"; method: "qris" | "transfer" | "cash"; invoiceId: string }
  | { kind: "bank"; bank: "bca" | "bni" | "bri" | "mandiri" | "permata"; invoiceId: string };

const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const BANKS = new Set(["bca", "bni", "bri", "mandiri", "permata"]);

export function normalizePhone(value: string): string | null {
  const digits = value.replace(/[^0-9]/g, "");
  const normalized = digits.startsWith("0") ? `62${digits.slice(1)}` : digits;
  return normalized.length >= 10 && normalized.length <= 15 ? normalized : null;
}

export function parseIncomingAction(value: string): IncomingAction {
  const raw = value.trim();
  const upper = raw.toLocaleUpperCase("id-ID");
  if (["STOP", "BERHENTI", "UNSUBSCRIBE", "HENTIKAN"].includes(upper)) {
    return { kind: "stop" };
  }
  if (["TAGIHAN", "BILL", "INVOICE", "MENU", "HELP", "BANTUAN", "START", "HALO", "HAI"].includes(upper)) {
    return { kind: upper === "TAGIHAN" || upper === "BILL" || upper === "INVOICE" ? "invoices" : "help" };
  }

  const invoiceMatch = raw.match(/^invoice:([0-9a-f-]+)$/i);
  if (invoiceMatch && UUID_PATTERN.test(invoiceMatch[1])) {
    return { kind: "invoice", invoiceId: invoiceMatch[1].toLowerCase() };
  }

  const payMatch = raw.match(/^pay:(qris|transfer|cash):([0-9a-f-]+)$/i);
  if (payMatch && UUID_PATTERN.test(payMatch[2])) {
    return {
      kind: "pay",
      method: payMatch[1].toLowerCase() as "qris" | "transfer" | "cash",
      invoiceId: payMatch[2].toLowerCase(),
    };
  }

  const bankMatch = raw.match(/^bank:([a-z]+):([0-9a-f-]+)$/i);
  if (bankMatch && BANKS.has(bankMatch[1].toLowerCase()) && UUID_PATTERN.test(bankMatch[2])) {
    return {
      kind: "bank",
      bank: bankMatch[1].toLowerCase() as "bca" | "bni" | "bri" | "mandiri" | "permata",
      invoiceId: bankMatch[2].toLowerCase(),
    };
  }
  return { kind: "help" };
}

export function constantTimeEqual(left: string, right: string): boolean {
  if (left.length > 512 || right.length > 512) return false;
  const a = new TextEncoder().encode(left);
  const b = new TextEncoder().encode(right);
  let difference = a.length ^ b.length;
  const maxLength = Math.max(a.length, b.length);
  for (let index = 0; index < maxLength; index++) {
    difference |= (a[index] ?? 0) ^ (b[index] ?? 0);
  }
  return difference === 0;
}

export async function verifyMetaSignature(
  rawBody: string,
  signatureHeader: string,
  appSecret: string,
): Promise<boolean> {
  if (!rawBody || !signatureHeader || !appSecret) return false;
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(appSecret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const digest = new Uint8Array(
    await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(rawBody)),
  );
  const signature = "sha256=" + Array.from(
    digest,
    (byte) => byte.toString(16).padStart(2, "0"),
  ).join("");
  return constantTimeEqual(signature, signatureHeader.trim().toLowerCase());
}

export function isUuid(value: string): boolean {
  return UUID_PATTERN.test(value);
}

export class MetaSendOutcomeError extends Error {
  constructor(message: string, readonly outcome: "rejected" | "unknown") {
    super(message);
    this.name = "MetaSendOutcomeError";
  }
}
