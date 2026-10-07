/**
 * Payment Gateway Abstraction Interface.
 * Vendor-agnostic contracts for payment processing.
 */

export interface CreatePaymentParams {
  orderId: string;
  grossAmount: number;
  customerDetails: {
    firstName: string;
    email: string;
    phone?: string;
  };
  itemDetails: Array<{
    id: string;
    price: number;
    quantity: number;
    name: string;
  }>;
  customExpiryMinutes?: number;
}

export interface QrPaymentResult {
  provider: string;
  transactionId: string;
  orderId: string;
  qrString: string;
  qrImageUrl?: string;
  expiresAt: string;
  rawResponse: Record<string, unknown>;
}

export interface BankTransferResult {
  provider: string;
  transactionId: string;
  orderId: string;
  bank: string;
  vaNumber: string;
  expiresAt: string;
  rawResponse: Record<string, unknown>;
}

export interface WebhookVerificationResult {
  isValid: boolean;
  orderId: string;
  transactionId: string;
  transactionStatus: string;
  grossAmount: number;
  statusCode: string;
  paymentType: string;
  rawBody: Record<string, unknown>;
}

export interface TransactionStatusResult {
  orderId: string;
  transactionId: string;
  transactionStatus: string;
  grossAmount: number;
  paymentType: string;
  settlementTime?: string;
}

export interface PaymentGatewayProvider {
  readonly name: string;
  createQrPayment(params: CreatePaymentParams): Promise<QrPaymentResult>;
  createBankTransfer(
    params: CreatePaymentParams,
    bank: string,
  ): Promise<BankTransferResult>;
  getTransactionStatus(orderId: string): Promise<TransactionStatusResult>;
  verifyWebhook(
    rawBody: Record<string, unknown>,
  ): Promise<WebhookVerificationResult>;
  cancelOrExpire(orderId: string): Promise<boolean>;
}
