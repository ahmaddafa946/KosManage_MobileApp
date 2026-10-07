import 'package:flutter_test/flutter_test.dart';
import 'package:kos_manage_mobile/domain/models/payment_transaction.dart';

void main() {
  group('PaymentTransaction Model', () {
    test('fromJson parses correctly', () {
      final json = {
        'id': 'tx_123',
        'payment_id': 'pay_456',
        'tenant_id': 'tenant_789',
        'order_id': 'order_000',
        'payment_method': 'qris',
        'payment_provider': 'midtrans',
        'gross_amount': 1500000,
        'status': 'pending',
        'qr_url': 'https://example.com/qr',
        'expires_at': DateTime.now().add(const Duration(minutes: 15)).toIso8601String(),
      };

      final tx = PaymentTransaction.fromJson(json);

      expect(tx.id, 'tx_123');
      expect(tx.paymentId, 'pay_456');
      expect(tx.tenantId, 'tenant_789');
      expect(tx.orderId, 'order_000');
      expect(tx.paymentMethod, 'qris');
      expect(tx.paymentProvider, 'midtrans');
      expect(tx.grossAmount, 1500000);
      expect(tx.status, 'pending');
      expect(tx.qrUrl, 'https://example.com/qr');
      expect(tx.isExpired, isFalse);
    });

    test('isExpired returns true for past dates', () {
      final tx = PaymentTransaction(
        id: '1',
        paymentId: '2',
        tenantId: '3',
        orderId: '4',
        paymentMethod: 'cash',
        paymentProvider: 'manual',
        grossAmount: 100,
        status: 'pending',
        expiresAt: DateTime.now().subtract(const Duration(minutes: 5)).toIso8601String(),
      );

      expect(tx.isExpired, isTrue);
    });
  });
}
