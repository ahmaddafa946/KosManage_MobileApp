import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kos_manage_mobile/domain/models/owner_management.dart';
import 'package:kos_manage_mobile/features/tenant/presentation/payment_flow.dart';

void main() {
  testWidgets(
    'payment selection sheet does not report hidden ListTile ink effects',
    (tester) async {
      final invoice = OwnerPayment(
        id: 'invoice-test',
        billingPeriod: '2026-10',
        dueDate: '2026-10-11',
        amountDue: 1400000,
        amountPaid: 0,
        status: 'unpaid',
      );

      final errors = <FlutterErrorDetails>[];
      final previousOnError = FlutterError.onError;
      FlutterError.onError = errors.add;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PaymentSelectionSheet(invoice: invoice),
          ),
        ),
      );
      await tester.pump();

      FlutterError.onError = previousOnError;

      expect(
        errors.where(
          (details) => details
              .exceptionAsString()
              .contains('ListTile background color or ink splashes may be invisible'),
        ),
        isEmpty,
      );
    },
  );
}
