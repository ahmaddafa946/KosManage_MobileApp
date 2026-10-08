import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kos_manage_mobile/domain/models/owner_dashboard_data.dart';
import 'package:kos_manage_mobile/features/owner/application/owner_dashboard_provider.dart';
import 'package:kos_manage_mobile/features/owner/presentation/owner_dashboard_page.dart';

void main() {
  testWidgets(
    'dashboard expiry card shows remaining rental days',
    (tester) async {
      final dashboard = OwnerDashboardData(
        propertyId: 'property-1',
        propertyName: 'Kos Melati',
        totalRooms: 10,
        occupiedRooms: 8,
        availableRooms: 2,
        maintenanceRooms: 0,
        activeTenants: 8,
        paidThisMonth: 12000000,
        totalOutstanding: 0,
        recentPayments: const [],
        upcomingPayments: const [],
        overduePayments: const [],
        activeMaintenance: const [],
        expiringTenants: [
          ExpiringTenantPreview(
            id: 'tenant-1',
            name: 'Sari',
            roomNumber: 'A-101',
            endDate: DateTime.now().add(const Duration(days: 10)),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ownerDashboardProvider.overrideWith((ref) async => dashboard),
          ],
          child: const MaterialApp(
            home: Scaffold(body: OwnerDashboardPage()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sari'), findsOneWidget);
      expect(find.text('Sisa 10 hari'), findsOneWidget);
    },
  );

  testWidgets(
    'dashboard expiry card shows today status when rental ends today',
    (tester) async {
      final dashboard = OwnerDashboardData(
        propertyId: 'property-1',
        propertyName: 'Kos Melati',
        totalRooms: 10,
        occupiedRooms: 8,
        availableRooms: 2,
        maintenanceRooms: 0,
        activeTenants: 8,
        paidThisMonth: 12000000,
        totalOutstanding: 0,
        recentPayments: const [],
        upcomingPayments: const [],
        overduePayments: const [],
        activeMaintenance: const [],
        expiringTenants: [
          ExpiringTenantPreview(
            id: 'tenant-1',
            name: 'Budi',
            roomNumber: 'A-102',
            endDate: DateTime.now(),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ownerDashboardProvider.overrideWith((ref) async => dashboard),
          ],
          child: const MaterialApp(
            home: Scaffold(body: OwnerDashboardPage()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Budi'), findsOneWidget);
      expect(find.text('Berakhir hari ini'), findsOneWidget);
    },
  );
}
