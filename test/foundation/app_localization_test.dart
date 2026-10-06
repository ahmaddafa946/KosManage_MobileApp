import 'package:flutter_test/flutter_test.dart';

import 'package:kos_manage_mobile/core/bootstrap/app_bootstrap.dart';
import 'package:kos_manage_mobile/domain/services/owner_display.dart';

void main() {
  test('initializes Indonesian locale before date and currency formatting', () async {
    await initializeAppLocalization();

    expect(formatDateId('2026-10-06'), '06 Okt 2026');
    expect(formatRupiah(1500000), contains('1.500.000'));
  });
}
