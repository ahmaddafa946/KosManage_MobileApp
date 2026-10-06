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
  const tenantProfile = UserProfile(
    id: 'tenant-user-1',
    name: 'Siti Nurhaliza Panjang Sekali Namanya Untuk Menguji Responsif',
    role: AppRole.tenant,
    email: 'siti@kos.id',
  );

  final mockTenant = OwnerTenant(
    id: 'tenant-1',
    name: 'Siti Nurhaliza Panjang Sekali Namanya Untuk Menguji Responsif',
    status: 'active',
    startDate: '2026-01-01',
    endDate: '2026-12-31',
    roomId: 'room-101',
    roomNumber: 'A-101',
    rentPrice: 1500000,
    deposit: 500000,
    phone: '081234567890',
    email: 'siti@kos.id',
    notes: 'Penghuni lantai 1 menghadap taman kos',
  );

  MyTenant mockMyTenant() =>
      MyTenant(propertyId: 'prop-1', tenant: mockTenant);

  final viewports = [
    const Size(360, 800), // Small Android
    const Size(390, 844), // iPhone / Normal
    const Size(412, 915), // Large Android
  ];

  TenantRepository fakeRepo() => _FakeTenantRepository(mockMyTenant());

  for (final size in viewports) {
    testWidgets(
      'TenantShell renders all 4 tabs without overflow on ${size.width.toInt()}x${size.height.toInt()}',
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
                tenantRepositoryProvider.overrideWith((ref) => fakeRepo()),
                currentTenantProvider.overrideWith(
                  (ref) async => mockMyTenant(),
                ),
              ],
              child: const MaterialApp(
                home: TenantShellPage(profile: tenantProfile),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Check Beranda tab
          expect(find.text('Beranda Saya'), findsOneWidget);
          expect(find.byType(NavigationDestination), findsNWidgets(4));

          // Tap Kamar tab (index 1)
          await tester.tap(find.text('Kamar'));
          await tester.pumpAndSettle();
          expect(find.text('Kamar Saya'), findsOneWidget);

          // Tap Tagihan tab (index 2)
          await tester.tap(find.text('Tagihan'));
          await tester.pumpAndSettle();
          expect(find.text('Tagihan & Riwayat'), findsOneWidget);

          // Tap Bantuan tab (index 3)
          await tester.tap(find.text('Bantuan'));
          await tester.pumpAndSettle();
          expect(find.text('Bantuan & Laporan'), findsOneWidget);

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
}

class _FakeTenantRepository implements TenantRepository {
  _FakeTenantRepository(this.myTenant);

  final MyTenant myTenant;
  @override
  Future<MyTenant> getMyTenant(String profileId) async {
    throw UnimplementedError();
  }

  @override
  Future<MyTenant> getMyTenantByEmail(String email) async {
    throw UnimplementedError();
  }

  @override
  Future<List<OwnerPayment>> getMyPayments(
    String propertyId,
    String tenantId,
  ) async {
    return const [];
  }

  @override
  Future<List<OwnerMaintenanceReport>> getMyReports(String tenantId) async {
    return const [];
  }

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
