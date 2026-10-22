export const MAX_REMINDERS = 3;
export const REMINDER_INTERVAL_MS = 3 * 24 * 60 * 60 * 1000;
export const REMINDER_RETRY_MS = 24 * 60 * 60 * 1000;

export function normalizePhone(value: string): string | null {
  const digits = value.replace(/[^0-9]/g, "").replace(/^0/, "62");
  return digits.length >= 10 && digits.length <= 15 ? digits : null;
}

export function outstandingAmount(amountDue: number, amountPaid: number): number {
  return Math.max(0, Number(amountDue) - Number(amountPaid));
}

export function nextReminderAt(now: Date, reminderCount: number): string | null {
  if (reminderCount >= MAX_REMINDERS) return null;
  return new Date(now.getTime() + REMINDER_INTERVAL_MS).toISOString();
}

export function retryAt(now: Date): string {
  return new Date(now.getTime() + REMINDER_RETRY_MS).toISOString();
}
