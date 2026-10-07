import 'package:flutter_test/flutter_test.dart';
import 'package:kos_manage_mobile/domain/models/payment_notification.dart';

void main() {
  group('PaymentNotification Model', () {
    test('fromJson parses correctly', () {
      final json = {
        'id': 'notif_1',
        'profile_id': 'prof_1',
        'title': 'Payment Success',
        'message': 'Your payment was successful.',
        'type': 'payment_success',
        'is_read': false,
        'created_at': '2026-10-08T00:00:00Z',
        'data': {'transaction_id': 'tx_123'}
      };

      final notif = PaymentNotification.fromJson(json);

      expect(notif.id, 'notif_1');
      expect(notif.profileId, 'prof_1');
      expect(notif.title, 'Payment Success');
      expect(notif.message, 'Your payment was successful.');
      expect(notif.type, 'payment_success');
      expect(notif.isRead, isFalse);
      expect(notif.createdAt, '2026-10-08T00:00:00Z');
      expect(notif.data?['transaction_id'], 'tx_123');
    });
  });
}
