import 'package:flutter_test/flutter_test.dart';

import 'package:kos_manage_mobile/domain/services/payment_transaction_status.dart';

void main() {
  group('payment transaction status policy', () {
    test('treats waiting_confirmation as an active transaction', () {
      expect(isActivePaymentTransactionStatus('waiting_confirmation'), isTrue);
    });

    test('syncs gateway state only for gateway-owned active states', () {
      expect(shouldSyncPaymentGatewayStatus('created'), isTrue);
      expect(shouldSyncPaymentGatewayStatus('pending'), isTrue);
      expect(shouldSyncPaymentGatewayStatus('waiting_confirmation'), isFalse);
      expect(shouldSyncPaymentGatewayStatus('success'), isFalse);
    });


    test('refreshes tenant bill data when a transaction reaches a terminal state', () {
      expect(shouldRefreshTenantPaymentData('success'), isTrue);
      expect(shouldRefreshTenantPaymentData('failed'), isTrue);
      expect(shouldRefreshTenantPaymentData('expired'), isTrue);
      expect(shouldRefreshTenantPaymentData('cancelled'), isTrue);
      expect(shouldRefreshTenantPaymentData('pending'), isFalse);
      expect(shouldRefreshTenantPaymentData('waiting_confirmation'), isFalse);
    });

    test('recognizes terminal payment states', () {
      expect(isTerminalPaymentTransactionStatus('success'), isTrue);
      expect(isTerminalPaymentTransactionStatus('failed'), isTrue);
      expect(isTerminalPaymentTransactionStatus('expired'), isTrue);
      expect(isTerminalPaymentTransactionStatus('cancelled'), isTrue);
      expect(isTerminalPaymentTransactionStatus('pending'), isFalse);
    });
  });
}
