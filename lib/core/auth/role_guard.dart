import '../../domain/models/app_role.dart';

/// Centralized role authorization logic for client routes and capabilities.
abstract final class RoleGuard {
  static const Set<String> _ownerPrefixes = {
    '/owner',
    '/rooms',
    '/tenants',
    '/payments',
    '/reports',
  };

  /// Returns true if [path] is strictly an owner-only resource.
  static bool isOwnerRoute(String path) {
    final normalized = path.toLowerCase();
    return _ownerPrefixes.any(
      (prefix) => normalized == prefix || normalized.startsWith('$prefix/'),
    );
  }

  /// Evaluates whether a [role] has permission to navigate to [path].
  static bool canAccess({required AppRole role, required String path}) {
    if (role == AppRole.owner) return true;
    if (isOwnerRoute(path)) return false;
    return true;
  }

  /// Capability guard: tenant payments are read-only.
  /// Only owner may create/update/delete official payment records.
  static bool canMutatePayments(AppRole role) => role == AppRole.owner;

  /// Capability guard: tenant may only create own maintenance report.
  static bool canCreateMaintenanceReport(AppRole role) =>
      role == AppRole.owner || role == AppRole.tenant;

  /// Resolves redirection destination when [requestedPath] violates role bounds.
  /// Returns null when access is allowed.
  static String? resolveRedirect({
    required AppRole role,
    required String requestedPath,
  }) {
    if (!canAccess(role: role, path: requestedPath)) {
      return '/home';
    }
    return null;
  }
}
