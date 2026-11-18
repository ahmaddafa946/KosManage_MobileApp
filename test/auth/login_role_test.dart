import 'package:flutter_test/flutter_test.dart';
import 'package:kos_manage_mobile/features/auth/presentation/login_role.dart';

void main() {
  group('ownerOnlyLoginMessage', () {
    test('allows owner accounts', () {
      expect(ownerOnlyLoginMessage(actualRole: 'owner'), isNull);
    });

    test('rejects tenant accounts with a clear message', () {
      expect(
        ownerOnlyLoginMessage(actualRole: 'tenant'),
        'Aplikasi KosManage Mobile hanya untuk pemilik kos.',
      );
    });

    test('rejects unknown roles by default', () {
      expect(
        ownerOnlyLoginMessage(actualRole: 'unknown'),
        'Aplikasi KosManage Mobile hanya untuk pemilik kos.',
      );
    });
  });
}
