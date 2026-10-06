import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kos_manage_mobile/domain/models/app_role.dart';
import 'package:kos_manage_mobile/domain/models/owner_dashboard_data.dart';
import 'package:kos_manage_mobile/domain/models/owner_management.dart';
import 'package:kos_manage_mobile/domain/models/user_profile.dart';
import 'package:kos_manage_mobile/features/home/presentation/home_gate_page.dart';
import 'package:kos_manage_mobile/features/owner/application/owner_dashboard_provider.dart';
import 'package:kos_manage_mobile/features/owner/application/owner_module_providers.dart';
import 'package:kos_manage_mobile/features/owner/presentation/owner_shell_page.dart';
import 'package:kos_manage_mobile/features/tenant/presentation/tenant_shell_page.dart';

void main() {
  const ownerProfile = UserProfile(
    id: 'owner-1',
    name: 'Pak Budi',
    role: AppRole.owner,
    email: 'owner@kos.id',
  );

  const tenantProfile = UserProfile(
    id: 'tenant-1',
    name: 'Sari Ayu',
    role: AppRole.tenant,
    email: 'sari@kos.id',
  );

  const mockProperty = OwnerProperty(id: 'prop-1', name: 'Kos Melati');

  const mockDashboard = OwnerDashboardData(
    propertyId: 'prop-1',
    propertyName: 'Kos Melati',
    totalRooms: 10,
    occupiedRooms: 8,
    availableRooms: 2,
    maintenanceRooms: 0,
    activeTenants: 8,
    paidThisMonth: 12000000,
    totalOutstanding: 0,
    recentPayments: [],
    upcomingPayments: [],
    overduePayments: [],
    activeMaintenance: [],
    expiringTenants: [],
  );

  testWidgets('HomeGate routes owner profile to OwnerShellPage', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentProfileProvider.overrideWith((ref) async => ownerProfile),
          ownerPropertyProvider.overrideWith((ref) async => mockProperty),
          ownerDashboardProvider.overrideWith((ref) async => mockDashboard),
        ],
        child: const MaterialApp(home: HomeGatePage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(OwnerShellPage), findsOneWidget);
    expect(find.byType(TenantShellPage), findsNothing);
  });

  testWidgets('HomeGate routes tenant profile to TenantShellPage', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentProfileProvider.overrideWith((ref) async => tenantProfile),
          currentTenantProvider.overrideWith((ref) async => null),
        ],
        child: const MaterialApp(home: HomeGatePage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TenantShellPage), findsOneWidget);
    expect(find.byType(OwnerShellPage), findsNothing);
  });

  testWidgets('TenantShell has exactly 4 navigation destinations', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentTenantProvider.overrideWith((ref) async => null),
        ],
        child: const MaterialApp(
          home: TenantShellPage(profile: tenantProfile),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NavigationDestination), findsNWidgets(4));
    expect(find.text('Beranda'), findsOneWidget);
    expect(find.text('Kamar'), findsOneWidget);
    expect(find.text('Tagihan'), findsOneWidget);
    expect(find.text('Bantuan'), findsOneWidget);
    expect(find.text('Penghuni'), findsNothing);
    expect(find.text('Pembayaran'), findsNothing);
    expect(find.text('Laporan'), findsNothing);
  });
}
