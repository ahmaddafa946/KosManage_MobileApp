import 'package:flutter_test/flutter_test.dart';

import '../../lib/domain/services/owner_display.dart';

void main() {
  test('formats Indonesian labels for room and payment status', () {
    expect(roomStatusLabel('available'), 'Kosong');
    expect(roomStatusLabel('occupied'), 'Terisi');
    expect(roomStatusLabel('maintenance'), 'Maintenance');
    expect(paymentStatusLabel('partial'), 'Sebagian');
    expect(paymentMethodLabel('qris'), 'QRIS');
  });

  test('calculates rental countdown buckets from date-only values', () {
    final today = DateTime(2026, 10, 1);

    expect(rentalCountdown('2026-10-31', today: today).label, 'Sisa 30 hari');
    expect(rentalCountdown('2026-10-15', today: today).label, 'Sisa 14 hari');
    expect(rentalCountdown('2026-10-07', today: today).label, 'Sisa 6 hari');
    expect(
      rentalCountdown('2026-10-01', today: today).label,
      'Berakhir hari ini',
    );
    expect(rentalCountdown('2026-09-28', today: today).label, 'Lewat 3 hari');
  });
}
