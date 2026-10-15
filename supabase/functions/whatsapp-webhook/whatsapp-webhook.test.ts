import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  constantTimeEqual,
  normalizePhone,
  parseIncomingAction,
  verifyMetaSignature,
} from "./webhook-logic.ts";

async function signPayload(payload: string, secret: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const digest = new Uint8Array(
    await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(payload)),
  );
  return "sha256=" + Array.from(digest, (byte) => byte.toString(16).padStart(2, "0")).join("");
}

Deno.test("normalizes Indonesian phone numbers before tenant lookup", () => {
  assertEquals(normalizePhone("0812-3456-7890"), "6281234567890");
  assertEquals(normalizePhone("+62 812 3456 7890"), "6281234567890");
  assertEquals(normalizePhone("1234"), null);
});

Deno.test("verifies Meta HMAC signatures against the exact raw request body", async () => {
  const payload = '{"entry":[]}';
  const signature = await signPayload(payload, "test_app_secret");
  assertEquals(await verifyMetaSignature(payload, signature, "test_app_secret"), true);
  assertEquals(await verifyMetaSignature(payload + " ", signature, "test_app_secret"), false);
  assertEquals(await verifyMetaSignature(payload, signature, "wrong_secret"), false);
  assertEquals(await verifyMetaSignature(payload, "", "test_app_secret"), false);
});

Deno.test("parses text commands without inferring payment consent", () => {
  assertEquals(parseIncomingAction(" tagihan "), { kind: "invoices" });
  assertEquals(parseIncomingAction("STOP"), { kind: "stop" });
  assertEquals(parseIncomingAction("START"), { kind: "help" });
  assertEquals(parseIncomingAction("hello"), { kind: "help" });
});

Deno.test("accepts only known interactive action ids with UUID invoice ids", () => {
  const id = "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee";
  assertEquals(parseIncomingAction("invoice:" + id), { kind: "invoice", invoiceId: id });
  assertEquals(parseIncomingAction("pay:qris:" + id), { kind: "pay", method: "qris", invoiceId: id });
  assertEquals(parseIncomingAction("pay:transfer:" + id), { kind: "pay", method: "transfer", invoiceId: id });
  assertEquals(parseIncomingAction("pay:cash:" + id), { kind: "pay", method: "cash", invoiceId: id });
  assertEquals(parseIncomingAction("bank:mandiri:" + id), { kind: "bank", bank: "mandiri", invoiceId: id });
  assertEquals(parseIncomingAction("pay:admin:" + id), { kind: "help" });
  assertEquals(parseIncomingAction("invoice:not-a-uuid"), { kind: "help" });
});

Deno.test("rejects oversized webhook verification tokens without comparing them", () => {
  assertEquals(constantTimeEqual("x".repeat(513), "x".repeat(513)), false);
});
