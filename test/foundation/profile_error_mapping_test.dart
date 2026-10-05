import 'package:flutter_test/flutter_test.dart';

import 'package:kos_manage_mobile/core/errors/app_exception.dart';
import 'package:kos_manage_mobile/features/home/presentation/home_gate_page.dart';

void main() {
  test('profile errors map to distinct human messages', () {
    expect(
      profileErrorMessage(const SessionException()),
      'Sesi login tidak tersedia. Silakan masuk kembali.',
    );
    expect(
      profileErrorMessage(const NotFoundException('Profil hilang.')),
      'Profil hilang.',
    );
    expect(
      profileErrorMessage(const AuthorizationException()),
      'Anda tidak memiliki akses.',
    );
    expect(
      profileErrorMessage(Exception('SocketException: host lookup')),
      'Koneksi internet bermasalah.',
    );
  });
}
