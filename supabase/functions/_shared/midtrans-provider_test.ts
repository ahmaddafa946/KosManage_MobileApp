import {
  parseMidtransChargeResponse,
} from "./midtrans-provider.ts";

Deno.test("parses the QRIS charge response with typed actions", () => {
  const response = parseMidtransChargeResponse({
    status_code: "201",
    transaction_id: "trx-qris-001",
    transaction_status: "pending",
    expiry_time: "2026-10-08 01:30:00",
    qr_string: "000201...",
    actions: [
      {
        name: "generate-qr-code",
        method: "GET",
        url: "https://api.midtrans.com/v2/qris/trx-qris-001/qr-code",
      },
    ],
  });

  const qrAction = response.actions?.find(
    (action) => action.name === "generate-qr-code",
  );

  if (response.transaction_id !== "trx-qris-001") {
    throw new Error("transaction_id was not parsed");
  }
  if (response.qr_string !== "000201...") {
    throw new Error("qr_string was not parsed");
  }
  if (!qrAction?.url?.endsWith("/qr-code")) {
    throw new Error("QR action URL was not parsed");
  }
});

Deno.test("parses bank transfer VA response with typed VA numbers", () => {
  const response = parseMidtransChargeResponse({
    status_code: "201",
    transaction_id: "trx-va-001",
    transaction_status: "pending",
    expiry_time: "2026-10-09 01:30:00",
    va_numbers: [
      {
        bank: "bca",
        va_number: "1234567890",
      },
    ],
  });

  const vaNumber = response.va_numbers?.[0]?.va_number;

  if (vaNumber !== "1234567890") {
    throw new Error("VA number was not parsed");
  }
});

Deno.test("rejects a malformed Midtrans charge response", () => {
  try {
    parseMidtransChargeResponse({
      transaction_id: 12345,
      actions: "not-an-array",
    });
    throw new Error("malformed response was accepted");
  } catch (error) {
    if (
      !(error instanceof Error) ||
      error.message !== "Invalid Midtrans charge response"
    ) {
      throw error;
    }
  }
});
