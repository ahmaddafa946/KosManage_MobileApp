/**
 * Midtrans Core API v2 Implementation.
 * Implements PaymentGatewayProvider for QRIS Dynamic and Bank Transfer (VA).
 */
import type {
  CreatePaymentParams,
  QrPaymentResult,
  BankTransferResult,
  WebhookVerificationResult,
  TransactionStatusResult,
  PaymentGatewayProvider,
} from "./payment-provider.ts";

export interface MidtransAction {
  name?: string;
  method?: string;
  url?: string;
  [key: string]: unknown;
}

export interface MidtransVaNumber {
  bank?: string;
  va_number?: string;
  [key: string]: unknown;
}

export interface MidtransChargeResponse extends Record<string, unknown> {
  status_code?: string;
  status_message?: string | string[];
  transaction_id?: string;
  transaction_status?: string;
  fraud_status?: string;
  order_id?: string;
  gross_amount?: string;
  currency?: string;
  payment_type?: string;
  transaction_time?: string;
  settlement_time?: string;
  expiry_time?: string;
  qr_string?: string;
  actions?: MidtransAction[];
  va_numbers?: MidtransVaNumber[];
  permata_va_number?: string;
  biller_code?: string;
  bill_key?: string;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function readOptionalString(
  value: Record<string, unknown>,
  fieldName: string,
): string | undefined {
  const field = value[fieldName];

  if (field === undefined || field === null) {
    return undefined;
  }

  if (typeof field !== "string") {
    throw new Error("Invalid Midtrans charge response");
  }

  return field;
}

function readOptionalStringArray(
  value: Record<string, unknown>,
  fieldName: string,
): string[] | undefined {
  const field = value[fieldName];

  if (field === undefined || field === null) {
    return undefined;
  }

  if (
    !Array.isArray(field) ||
    field.some((item) => typeof item !== "string")
  ) {
    throw new Error("Invalid Midtrans charge response");
  }

  return field;
}

function readOptionalActions(
  value: Record<string, unknown>,
): MidtransAction[] | undefined {
  const field = value.actions;

  if (field === undefined || field === null) {
    return undefined;
  }

  if (!Array.isArray(field)) {
    throw new Error("Invalid Midtrans charge response");
  }

  return field.map((item) => {
    if (!isRecord(item)) {
      throw new Error("Invalid Midtrans charge response");
    }

    return {
      ...item,
      name: readOptionalString(item, "name"),
      method: readOptionalString(item, "method"),
      url: readOptionalString(item, "url"),
    };
  });
}

function readOptionalVaNumbers(
  value: Record<string, unknown>,
): MidtransVaNumber[] | undefined {
  const field = value.va_numbers;

  if (field === undefined || field === null) {
    return undefined;
  }

  if (!Array.isArray(field)) {
    throw new Error("Invalid Midtrans charge response");
  }

  return field.map((item) => {
    if (!isRecord(item)) {
      throw new Error("Invalid Midtrans charge response");
    }

    return {
      ...item,
      bank: readOptionalString(item, "bank"),
      va_number: readOptionalString(item, "va_number"),
    };
  });
}

/**
 * Validates and narrows the untrusted JSON returned by the Midtrans charge API.
 * This keeps downstream payment mapping strongly typed without using explicit-any casts.
 */
export function parseMidtransChargeResponse(
  payload: unknown,
): MidtransChargeResponse {
  if (!isRecord(payload)) {
    throw new Error("Invalid Midtrans charge response");
  }

  const parsed: MidtransChargeResponse = {
    ...payload,
    status_code: readOptionalString(payload, "status_code"),
    status_message:
      typeof payload.status_message === "string"
        ? payload.status_message
        : readOptionalStringArray(payload, "status_message"),
    transaction_id: readOptionalString(payload, "transaction_id"),
    transaction_status: readOptionalString(payload, "transaction_status"),
    fraud_status: readOptionalString(payload, "fraud_status"),
    order_id: readOptionalString(payload, "order_id"),
    gross_amount: readOptionalString(payload, "gross_amount"),
    currency: readOptionalString(payload, "currency"),
    payment_type: readOptionalString(payload, "payment_type"),
    transaction_time: readOptionalString(payload, "transaction_time"),
    settlement_time: readOptionalString(payload, "settlement_time"),
    expiry_time: readOptionalString(payload, "expiry_time"),
    qr_string: readOptionalString(payload, "qr_string"),
    actions: readOptionalActions(payload),
    va_numbers: readOptionalVaNumbers(payload),
    permata_va_number: readOptionalString(payload, "permata_va_number"),
    biller_code: readOptionalString(payload, "biller_code"),
    bill_key: readOptionalString(payload, "bill_key"),
  };

  return parsed;
}

export class MidtransPaymentProvider implements PaymentGatewayProvider {
  readonly name = "midtrans";

  private readonly serverKey: string;
  private readonly baseUrl: string;
  private readonly authHeader: string;

  constructor() {
    this.serverKey = Deno.env.get("MIDTRANS_SERVER_KEY") ?? "";
    const isProduction = Deno.env.get("MIDTRANS_IS_PRODUCTION") === "true";
    this.baseUrl = isProduction
      ? "https://api.midtrans.com/v2"
      : "https://api.sandbox.midtrans.com/v2";

    // Midtrans uses HTTP Basic Auth: base64(serverKey + ":")
    const credentials = btoa(`${this.serverKey}:`);
    this.authHeader = `Basic ${credentials}`;
  }

  async createQrPayment(params: CreatePaymentParams): Promise<QrPaymentResult> {
    const payload = {
      payment_type: "qris",
      transaction_details: {
        order_id: params.orderId,
        gross_amount: params.grossAmount,
      },
      item_details: params.itemDetails,
      customer_details: {
        first_name: params.customerDetails.firstName,
        email: params.customerDetails.email,
        phone: params.customerDetails.phone,
      },
      qris: { acquirer: "gopay" },
      custom_expiry: {
        expiry_duration: params.customExpiryMinutes ?? 15,
        unit: "minute",
      },
    };

    const res = await this.charge(payload);

    const expiresAt = res.expiry_time
      ? new Date(res.expiry_time.replace(" ", "T") + "+07:00").toISOString()
      : new Date(Date.now() + (params.customExpiryMinutes ?? 15) * 60_000).toISOString();

    // Extract QR URL from actions array if available
    const qrAction = res.actions?.find(
      (a) => a.name === "generate-qr-code",
    );

    return {
      provider: this.name,
      transactionId: res.transaction_id ?? "",
      orderId: params.orderId,
      qrString: res.qr_string ?? "",
      qrImageUrl: qrAction?.url,
      expiresAt,
      rawResponse: res,
    };
  }

  async createBankTransfer(
    params: CreatePaymentParams,
    bank: string,
  ): Promise<BankTransferResult> {
    const payload: Record<string, unknown> = {
      payment_type: "bank_transfer",
      transaction_details: {
        order_id: params.orderId,
        gross_amount: params.grossAmount,
      },
      item_details: params.itemDetails,
      customer_details: {
        first_name: params.customerDetails.firstName,
        email: params.customerDetails.email,
        phone: params.customerDetails.phone,
      },
      custom_expiry: {
        expiry_duration: 24,
        unit: "hour",
      },
    };

    // Mandiri uses echannel; others use bank_transfer
    if (bank === "mandiri") {
      payload.payment_type = "echannel";
      payload.echannel = {
        bill_info1: "Payment",
        bill_info2: "KosManage Rent",
      };
    } else {
      payload.bank_transfer = { bank };
    }

    const res = await this.charge(payload);

    // Extract VA number (different structure per bank)
    let vaNumber = "";
    if (bank === "mandiri") {
      vaNumber = `${res.biller_code ?? ""}${res.bill_key ?? ""}`;
    } else if (bank === "permata") {
      vaNumber = res.permata_va_number ?? "";
    } else {
      const vaEntry = res.va_numbers?.[0];
      vaNumber = vaEntry?.va_number ?? "";
    }

    const expiresAt = res.expiry_time
      ? new Date(res.expiry_time.replace(" ", "T") + "+07:00").toISOString()
      : new Date(Date.now() + 24 * 60 * 60_000).toISOString();

    return {
      provider: this.name,
      transactionId: res.transaction_id ?? "",
      orderId: params.orderId,
      bank,
      vaNumber,
      expiresAt,
      rawResponse: res,
    };
  }

  async verifyWebhook(
    rawBody: Record<string, unknown>,
  ): Promise<WebhookVerificationResult> {
    const orderId = String(rawBody.order_id ?? "");
    const statusCode = String(rawBody.status_code ?? "");
    const grossAmount = String(rawBody.gross_amount ?? "");
    const signatureKey = String(rawBody.signature_key ?? "");
    const transactionId = String(rawBody.transaction_id ?? "");
    const paymentType = String(rawBody.payment_type ?? "");

    let transactionStatus = String(rawBody.transaction_status ?? "");
    // Normalize: capture with fraud_status=accept -> settlement
    if (transactionStatus === "capture") {
      const fraudStatus = String(rawBody.fraud_status ?? "");
      transactionStatus = fraudStatus === "accept" ? "settlement" : "deny";
    }

    // Compute SHA-512 signature
    const rawString = `${orderId}${statusCode}${grossAmount}${this.serverKey}`;
    const encoder = new TextEncoder();
    const data = encoder.encode(rawString);
    const hashBuffer = await crypto.subtle.digest("SHA-512", data);
    const hashArray = Array.from(new Uint8Array(hashBuffer));
    const calculatedSignature = hashArray
      .map((b) => b.toString(16).padStart(2, "0"))
      .join("");

    const isValid = calculatedSignature === signatureKey;

    return {
      isValid,
      orderId,
      transactionId,
      transactionStatus,
      grossAmount: parseFloat(grossAmount) || 0,
      statusCode,
      paymentType,
      rawBody,
    };
  }

  async getTransactionStatus(
    orderId: string,
  ): Promise<TransactionStatusResult> {
    const res = await fetch(`${this.baseUrl}/${orderId}/status`, {
      method: "GET",
      headers: {
        Authorization: this.authHeader,
        Accept: "application/json",
      },
    });
    const data = await res.json();

    return {
      orderId: data.order_id ?? orderId,
      transactionId: data.transaction_id ?? "",
      transactionStatus: data.transaction_status ?? "unknown",
      grossAmount: parseFloat(data.gross_amount) || 0,
      paymentType: data.payment_type ?? "",
      settlementTime: data.settlement_time,
    };
  }

  async cancelOrExpire(orderId: string): Promise<boolean> {
    try {
      const res = await fetch(`${this.baseUrl}/${orderId}/cancel`, {
        method: "POST",
        headers: {
          Authorization: this.authHeader,
          Accept: "application/json",
        },
      });
      const data = await res.json();
      return data.status_code === "200" || data.status_code === "201";
    } catch {
      return false;
    }
  }

  private async charge(
    payload: Record<string, unknown>,
  ): Promise<MidtransChargeResponse> {
    const res = await fetch(`${this.baseUrl}/charge`, {
      method: "POST",
      headers: {
        Authorization: this.authHeader,
        "Content-Type": "application/json",
        Accept: "application/json",
      },
      body: JSON.stringify(payload),
    });

    const data = parseMidtransChargeResponse(await res.json());

    if (!res.ok && res.status !== 201) {
      const statusMessage = Array.isArray(data.status_message)
        ? data.status_message.join(", ")
        : data.status_message;
      throw new Error(
        `Midtrans charge failed: ${statusMessage ?? res.statusText}`,
      );
    }

    return data;
  }
}

/**
 * Factory function to get the active payment gateway.
 */
export function getPaymentGateway(): PaymentGatewayProvider {
  return new MidtransPaymentProvider();
}
