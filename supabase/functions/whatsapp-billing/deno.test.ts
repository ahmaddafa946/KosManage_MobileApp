import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  MAX_REMINDERS,
  nextReminderAt,
  normalizePhone,
  outstandingAmount,
  retryAt,
} from "./reminder-logic.ts";

Deno.test("normalizes Indonesian local numbers to country code 62", () => {
  assertEquals(normalizePhone("0812-3456-7890"), "6281234567890");
});

Deno.test("accepts international digits and rejects short phone numbers", () => {
  assertEquals(normalizePhone("+6281234567890"), "6281234567890");
  assertEquals(normalizePhone("12345"), null);
});

Deno.test("never reports a negative outstanding amount", () => {
  assertEquals(outstandingAmount(1000000, 200000), 800000);
  assertEquals(outstandingAmount(1000000, 1200000), 0);
});

Deno.test("schedules the next reminder three days later", () => {
  const now = new Date("2026-10-16T00:00:00.000Z");
  assertEquals(nextReminderAt(now, 0), "2026-10-19T00:00:00.000Z");
});

Deno.test("stops scheduling after the maximum number of reminders", () => {
  const now = new Date("2026-10-16T00:00:00.000Z");
  assertEquals(MAX_REMINDERS, 3);
  assertEquals(nextReminderAt(now, MAX_REMINDERS), null);
});

Deno.test("backs off a failed reminder for 24 hours", () => {
  const now = new Date("2026-10-16T00:00:00.000Z");
  assertEquals(retryAt(now), "2026-10-17T00:00:00.000Z");
});
