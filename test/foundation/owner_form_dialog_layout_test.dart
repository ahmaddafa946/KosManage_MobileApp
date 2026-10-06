import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kos_manage_mobile/domain/models/owner_management.dart';
import 'package:kos_manage_mobile/features/owner/presentation/payments_page.dart';

void main() {
  testWidgets(
    'owner form dialog surface renders long tenant selector without layout errors',
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
                child: Dialog(
                  insetPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 24,
                  ),
                  child: SizedBox(
                    width: 280,
                    height: 600,
                    child: Column(
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text('Catat Pembayaran'),
                          ),
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              children: [
                                OwnerTenantDropdownField(
                                  tenants: [tenant],
                                  value: null,
                                  enabled: true,
                                  onChanged: (_) {},
                                ),
                                const SizedBox(height: 12),
                                const TextField(
                                  decoration: InputDecoration(
                                    labelText: 'Periode',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const TextField(
                                  decoration: InputDecoration(
                                    labelText: 'Tagihan (Rp)',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text('Batal'),
                              SizedBox(width: 16),
                              Text('Simpan'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Catat Pembayaran'), findsOneWidget);
        expect(find.byType(OwnerTenantDropdownField), findsOneWidget);
        expect(find.text('Tagihan (Rp)'), findsOneWidget);
      } finally {
        FlutterError.onError = previousOnError;
      }

      expect(
        errors
            .where(
              (error) =>
                  error.exceptionAsString().contains('overflowed') ||
                  error.exceptionAsString().contains('RenderFlex'),
            )
            .toList(),
        isEmpty,
      );
    },
  );
}
