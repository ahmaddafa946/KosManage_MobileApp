import 'package:flutter_test/flutter_test.dart';
import 'package:kos_manage_mobile/features/auth/presentation/login_role.dart';

void main() {
  group('roleMismatchMessage', () {
    test('returns no message when a pemilik selects their own role', () {
      expect(
        roleMismatchMessage(selectedRole: 'owner', actualRole: 'owner'),
        isNull,
      );
    });

    test('returns no message when a penghuni selects their own role', () {
      expect(
        roleMismatchMessage(selectedRole: 'tenant', actualRole: 'tenant'),
        isNull,
      );
    });

    test('explains when a pemilik account selects penghuni', () {
      expect(
        roleMismatchMessage(selectedRole: 'tenant', actualRole: 'owner'),
        'Akun ini terdaftar sebagai pemilik kos. '
        'Pilih tab yang sesuai, lalu coba lagi.',
      );
    });

    test('explains when a penghuni account selects pemilik', () {
      expect(
        roleMismatchMessage(selectedRole: 'owner', actualRole: 'tenant'),
        'Akun ini terdaftar sebagai penghuni. '
        'Pilih tab yang sesuai, lalu coba lagi.',
      );
    });
  });
}
