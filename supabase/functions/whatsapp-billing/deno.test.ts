import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";

function normalizePhone(value: string): string | null {
  const digits = value.replace(/[^0-9]/g, "").replace(/^0/, "62");
  return digits.length >= 10 && digits.length <= 15 ? digits : null;
}
function outstanding(amountDue: number, amountPaid: number): number {
  return Math.max(0, amountDue - amountPaid);
}
Deno.test("normalizes Indonesian local numbers to country code 62", () => {
  assertEquals(normalizePhone("0812-3456-7890"), "6281234567890");
});
Deno.test("accepts international digits and rejects short phone numbers", () => {
  assertEquals(normalizePhone("+6281234567890"), "6281234567890");
  assertEquals(normalizePhone("12345"), null);
});
Deno.test("never reports a negative outstanding amount", () => {
  assertEquals(outstanding(1000000, 200000), 800000);
  assertEquals(outstanding(1000000, 1200000), 0);
});
