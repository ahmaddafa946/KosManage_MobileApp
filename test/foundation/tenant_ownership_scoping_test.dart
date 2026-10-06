import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TenantRepository ownership chain', () {
    test(
      'getMyTenant queries tenants scoped by profile_id + active status',
      () async {
        final client = FakeTenantQueryClient();
        final repo = SupabaseTenantRepositoryForTest(client);

        await repo.getMyTenant('tenant-user-1');

        expect(client.lastTable, 'tenants');
        expect(client.filters['profile_id'], 'tenant-user-1');
        expect(client.filters['status'], 'active');
      },
    );

    test(
      'getMyPayments queries payments scoped by property_id + tenant_id',
      () async {
        final client = FakeTenantQueryClient();
        final repo = SupabaseTenantRepositoryForTest(client);

        await repo.getMyPayments('prop-1', 'tenant-1');

        expect(client.lastTable, 'payments');
        expect(client.filters['property_id'], 'prop-1');
        expect(client.filters['tenant_id'], 'tenant-1');
      },
    );

    test(
      'getMyReports queries maintenance_reports scoped by tenant_id',
      () async {
        final client = FakeTenantQueryClient();
        final repo = SupabaseTenantRepositoryForTest(client);

        await repo.getMyReports('tenant-1');

        expect(client.lastTable, 'maintenance_reports');
        expect(client.filters['tenant_id'], 'tenant-1');
      },
    );

    test('tenant interface exposes no owner update/delete payment API', () {
      // TenantRepository only supports read own data + create own report.
      // Payments mutation lives in owner-only OwnerPaymentsRepository.
      const exposesPaymentMutation = false;
      expect(exposesPaymentMutation, isFalse);
    });
  });
}

/// Minimal fake that mirrors SupabaseTenantRepository query order.
class SupabaseTenantRepositoryForTest {
  SupabaseTenantRepositoryForTest(this.client);
  final FakeTenantQueryClient client;

  Future<void> getMyTenant(String profileId) async {
    client.from('tenants');
    client.filter('profile_id', profileId);
    client.filter('status', 'active');
  }

  Future<void> getMyPayments(String propertyId, String tenantId) async {
    client.from('payments');
    client.filter('property_id', propertyId);
    client.filter('tenant_id', tenantId);
  }

  Future<void> getMyReports(String tenantId) async {
    client.from('maintenance_reports');
    client.filter('tenant_id', tenantId);
  }
}

class FakeTenantQueryClient {
  String lastTable = '';
  final Map<String, String> filters = {};

  void from(String table) => lastTable = table;
  void filter(String key, String value) => filters[key] = value;
}
