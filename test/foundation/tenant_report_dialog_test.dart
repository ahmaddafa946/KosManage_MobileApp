import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kos_manage_mobile/data/repositories/tenant_repository.dart';
import 'package:kos_manage_mobile/domain/models/app_role.dart';
import 'package:kos_manage_mobile/domain/models/owner_management.dart';
import 'package:kos_manage_mobile/domain/models/user_profile.dart';
import 'package:kos_manage_mobile/features/tenant/presentation/tenant_shell_page.dart';

void main() {
  MyTenant mockMyTenant() => MyTenant(
    propertyId: 'prop-1',
    tenant: OwnerTenant(
      id: 'tenant-1',
      name: 'Siti',
      status: 'active',
      startDate: '2026-01-01',
      endDate: '2026-12-31',
      roomId: 'room-101',
      roomNumber: 'A-101 Panjang Untuk Uji Responsif Mobile Layout',
      rentPrice: 1500000,
      deposit: 500000,
    ),
  );

  final viewports = [const Size(360, 800), const Size(390, 844), const Size(412, 915)];

  for (final size in viewports) {
    testWidgets(
      'maintenance report dialog has no overflow on ${size.width.toInt()}x${size.height.toInt()}',
      (tester) async {
        final errors = <FlutterErrorDetails>[];
        final previousOnError = FlutterError.onError;
        FlutterError.onError = errors.add;
        try {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                tenantRepositoryProvider.overrideWith(
                  (ref) => _FakeTenantRepository(),
                ),
              ],
              child: MaterialApp(home: TenantReportDialog(myTenant: mockMyTenant())),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('Lapor Kerusakan'), findsOneWidget);
          expect(find.text('Judul keluhan'), findsOneWidget);
          expect(find.text('Deskripsi keluhan'), findsOneWidget);
          expect(find.text('Kirim'), findsOneWidget);

          // Empty submit shows human validation error.
          await tester.tap(find.text('Kirim'));
          await tester.pump();
          expect(find.text('Judul dan deskripsi wajib diisi.'), findsOneWidget);

          expect(
            errors.where((e) => e.toString().contains('OVERFLOWED')),
            isEmpty,
          );
        } finally {
          FlutterError.onError = previousOnError;
        }
      },
    );
  }

  testWidgets('tenant home shows loading then empty state', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tenantRepositoryProvider.overrideWith((ref) => _FakeTenantRepository()),
          currentTenantProvider.overrideWith((ref) async => null),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: TenantHome(
              profile: UserProfile(
                id: 'tenant-user-1',
                name: 'Siti',
                role: AppRole.tenant,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Belum Terhubung Kamar'), findsOneWidget);
  });
}

class _FakeTenantRepository implements TenantRepository {
  @override
  Future<MyTenant> getMyTenant(String profileId) async => throw UnimplementedError();
  @override
  Future<MyTenant> getMyTenantByEmail(String email) async => throw UnimplementedError();
  @override
  Future<List<OwnerPayment>> getMyPayments(String propertyId, String tenantId) async => const [];
  @override
  Future<List<OwnerMaintenanceReport>> getMyReports(String tenantId) async => const [];
  @override
  Future<void> createReport({
    required String propertyId,
    required String tenantId,
    required String? roomId,
    required String title,
    required String description,
    required String category,
    required String priority,
    File? photo,
  }) async {}
}
