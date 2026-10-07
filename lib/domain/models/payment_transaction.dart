class PaymentTransaction {
  const PaymentTransaction({
    required this.id,
    required this.paymentId,
    required this.tenantId,
    required this.orderId,
    required this.paymentMethod,
    required this.paymentProvider,
    required this.grossAmount,
    required this.status,
    this.vaNumber,
    this.bank,
    this.qrString,
    this.qrUrl,
    this.gatewayReference,
    this.expiresAt,
    this.paidAt,
    this.createdAt,
  });

  final String id;
  final String paymentId;
  final String tenantId;
  final String orderId;
  final String paymentMethod;
  final String paymentProvider;
  final num grossAmount;
  final String status;
  final String? vaNumber;
  final String? bank;
  final String? qrString;
  final String? qrUrl;
  final String? gatewayReference;
  final String? expiresAt;
  final String? paidAt;
  final String? createdAt;

  factory PaymentTransaction.fromJson(Map<String, dynamic> json) {
    return PaymentTransaction(
      id: json['id'] as String,
      paymentId: json['payment_id'] as String,
      tenantId: json['tenant_id'] as String,
      orderId: json['order_id'] as String,
      paymentMethod: json['payment_method'] as String,
      paymentProvider: json['payment_provider'] as String,
      grossAmount: json['gross_amount'] as num? ?? 0,
      status: json['status'] as String,
      vaNumber: json['va_number'] as String?,
      bank: json['bank'] as String?,
      qrString: json['qr_string'] as String?,
      qrUrl: json['qr_url'] as String?,
      gatewayReference: json['gateway_reference'] as String?,
      expiresAt: json['expires_at'] as String?,
      paidAt: json['paid_at'] as String?,
      createdAt: json['created_at'] as String?,
    );
  }

  bool get isExpired {
    if (expiresAt == null) return false;
    final exp = DateTime.tryParse(expiresAt!);
    if (exp == null) return false;
    return DateTime.now().isAfter(exp);
  }
}
