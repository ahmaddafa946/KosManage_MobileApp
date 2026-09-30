import 'package:flutter_test/flutter_test.dart';
import 'package:kos_manage_mobile/domain/models/app_role.dart';

void main() {
  group('AppRole.fromDatabase', () {
    test('maps owner to owner', () {
      expect(AppRole.fromDatabase('owner'), AppRole.owner);
    });

    test('maps tenant to tenant', () {
      expect(AppRole.fromDatabase('tenant'), AppRole.tenant);
    });

    test('rejects unknown roles', () {
      expect(
        () => AppRole.fromDatabase('admin'),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
