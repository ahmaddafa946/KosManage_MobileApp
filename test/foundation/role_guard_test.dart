import 'package:flutter_test/flutter_test.dart';

import 'package:kos_manage_mobile/core/auth/role_guard.dart';
import 'package:kos_manage_mobile/domain/models/app_role.dart';

void main() {
  group('RoleGuard route access', () {
    test('owner can access owner and shared routes', () {
      expect(RoleGuard.canAccess(role: AppRole.owner, path: '/owner/rooms'), isTrue);
      expect(RoleGuard.canAccess(role: AppRole.owner, path: '/owner/tenants'), isTrue);
      expect(RoleGuard.canAccess(role: AppRole.owner, path: '/owner/payments'), isTrue);
      expect(RoleGuard.canAccess(role: AppRole.owner, path: '/owner/reports'), isTrue);
      expect(RoleGuard.canAccess(role: AppRole.owner, path: '/home'), isTrue);
      expect(RoleGuard.canAccess(role: AppRole.owner, path: '/settings'), isTrue);
    });

    test('tenant is blocked from owner routes', () {
      expect(RoleGuard.canAccess(role: AppRole.tenant, path: '/owner/rooms'), isFalse);
      expect(RoleGuard.canAccess(role: AppRole.tenant, path: '/owner/tenants'), isFalse);
      expect(RoleGuard.canAccess(role: AppRole.tenant, path: '/owner/payments'), isFalse);
      expect(RoleGuard.canAccess(role: AppRole.tenant, path: '/owner/reports'), isFalse);
      expect(RoleGuard.canAccess(role: AppRole.tenant, path: '/owner/dashboard'), isFalse);
    });

    test('tenant is blocked from all routes in owner-only mobile app', () {
      expect(RoleGuard.canAccess(role: AppRole.tenant, path: '/home'), isFalse);
      expect(RoleGuard.canAccess(role: AppRole.tenant, path: '/settings'), isFalse);
      expect(RoleGuard.canAccess(role: AppRole.tenant, path: '/profile'), isFalse);
      expect(RoleGuard.canAccess(role: AppRole.tenant, path: '/tenant/bills'), isFalse);
      expect(RoleGuard.canAccess(role: AppRole.tenant, path: '/tenant/help'), isFalse);
    });

    test('redirectPath redirects tenant away from owner routes to /home', () {
      expect(
        RoleGuard.resolveRedirect(role: AppRole.tenant, requestedPath: '/owner/rooms'),
        '/home',
      );
      expect(
        RoleGuard.resolveRedirect(role: AppRole.tenant, requestedPath: '/home'),
        '/home',
      );
      expect(
        RoleGuard.resolveRedirect(role: AppRole.tenant, requestedPath: '/settings'),
        '/home',
      );
      expect(
        RoleGuard.resolveRedirect(role: AppRole.owner, requestedPath: '/owner/rooms'),
        isNull,
      );
    });

    test('tenant payments are read-only, owner can mutate', () {
      expect(RoleGuard.canMutatePayments(AppRole.tenant), isFalse);
      expect(RoleGuard.canMutatePayments(AppRole.owner), isTrue);
    });

    test('only owner can create maintenance reports', () {
      expect(RoleGuard.canCreateMaintenanceReport(AppRole.tenant), isFalse);
      expect(RoleGuard.canCreateMaintenanceReport(AppRole.owner), isTrue);
    });
  });
}
