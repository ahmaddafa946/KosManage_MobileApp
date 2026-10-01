import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kos_manage_mobile/domain/models/owner_management.dart';
import 'package:kos_manage_mobile/features/owner/presentation/payments_page.dart';

void main() {
  testWidgets(
    'tenant selector does not overflow on a narrow mobile layout',
    (tester) async {
      final tenant = OwnerTenant(
        id: 'tenant-1',
        name: 'Nama Penghuni Sangat Panjang Untuk Uji Layout Mobile',
        status: 'active',
        startDate: '2026-10-01',
        roomNumber: 'A-102',
      );

      final errors = <FlutterErrorDetails>[];
      final previousOnError = FlutterError.onError;
      FlutterError.onError = errors.add;

      try {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 280,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: OwnerTenantDropdownField(
                      tenants: [tenant],
                      value: null,
                      enabled: true,
                      onChanged: (_) {},
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
      } finally {
        FlutterError.onError = previousOnError;
      }

      expect(
        errors
            .where(
              (error) => error.exceptionAsString().contains('overflowed'),
            )
            .toList(),
        isEmpty,
      );
    },
  );
}
