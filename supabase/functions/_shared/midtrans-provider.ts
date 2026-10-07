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
      (a: { name: string }) => a.name === "generate-qr-code",
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

  private async charge(payload: Record<string, unknown>): Promise<Record<string, unknown>> {
    const res = await fetch(`${this.baseUrl}/charge`, {
      method: "POST",
      headers: {
        Authorization: this.authHeader,
        "Content-Type": "application/json",
        Accept: "application/json",
      },
      body: JSON.stringify(payload),
    });
    // deno-lint-ignore no-explicit-any
    const data: any = await res.json();
    if (!res.ok && res.status !== 201) {
      throw new Error(
        `Midtrans charge failed: ${data.status_message ?? res.statusText}`,
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
