import 'package:flutter_test/flutter_test.dart';
import 'package:kos_manage_mobile/features/auth/presentation/demo_credentials.dart';

void main() {
  group('demoCredentialsForRole', () {
    test('returns owner demo credentials for the owner role', () {
      final credentials = demoCredentialsForRole('owner');

      expect(credentials.email, 'owner@kosmanage.dev');
      expect(credentials.password, 'KosManage!dev1');
    });

    test('returns tenant demo credentials for the tenant role', () {
      final credentials = demoCredentialsForRole('tenant');

      expect(credentials.email, 'tenant.demo@kosmanage.dev');
      expect(credentials.password, 'KosManage!dev2');
    });

    test('defaults unknown roles to owner demo credentials', () {
      expect(
        demoCredentialsForRole('unknown').email,
        'owner@kosmanage.dev',
      );
    });
  });
}
