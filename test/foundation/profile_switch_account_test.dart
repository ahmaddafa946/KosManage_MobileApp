import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kos_manage_mobile/domain/models/app_role.dart';
import 'package:kos_manage_mobile/domain/models/user_profile.dart';
import 'package:kos_manage_mobile/features/home/presentation/home_gate_page.dart';
import 'package:kos_manage_mobile/features/owner/presentation/owner_shell_page.dart';
import 'package:kos_manage_mobile/features/tenant/presentation/tenant_shell_page.dart';

/// Regression test: profile cache must not survive authenticated user switch.
/// tenant profile -> session/user changes -> owner profile must render owner.
void main() {
  const tenantProfile = UserProfile(
    id: 'tenant-user-1',
    name: 'Siti',
    role: AppRole.tenant,
    email: 'siti@kos.id',
  );

  const ownerProfile = UserProfile(
    id: 'owner-user-1',
    name: 'Pak Budi',
    role: AppRole.owner,
    email: 'owner@kos.id',
  );

  testWidgets(
    'HomeGate uses new owner profile after switching from tenant user',
    (tester) async {
      // Start as tenant user.
      var activeProfile = tenantProfile;

      Future<UserProfile> profileLoader(Ref ref) async => activeProfile;

      Future<void> pumpGate() async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentProfileProvider.overrideWith(profileLoader),
              currentTenantProvider.overrideWith((ref) async => null),
            ],
            child: const MaterialApp(home: HomeGatePage()),
          ),
        );
        await tester.pumpAndSettle();
      }

      await pumpGate();
      expect(find.byType(TenantShellPage), findsOneWidget);
      expect(find.byType(OwnerShellPage), findsNothing);

      // Simulate logout + login as different user: session/user changes,
      // profile source now returns owner. Provider must not reuse tenant.
      // Unmount first: real logout/login disposes the old scope.
      await tester.pumpWidget(const SizedBox());
      activeProfile = ownerProfile;

      await pumpGate();
      expect(find.byType(OwnerShellPage), findsOneWidget);
      expect(find.byType(TenantShellPage), findsNothing);
    },
  );

  test(
    'currentProfileProvider does not pin old user profile across scopes',
    () async {
      // Behavioral guard: each fresh ProviderScope must resolve the
      // currently active user, never a stale cached profile.
      var activeProfile = tenantProfile;
      Future<UserProfile> loader(Ref ref) async => activeProfile;

      final first = ProviderContainer(
        overrides: [currentProfileProvider.overrideWith(loader)],
      );
      expect(await first.read(currentProfileProvider.future), tenantProfile);
      first.dispose();

      activeProfile = ownerProfile;
      final second = ProviderContainer(
        overrides: [currentProfileProvider.overrideWith(loader)],
      );
      expect(await second.read(currentProfileProvider.future), ownerProfile);
      second.dispose();
    },
  );
}
