import 'package:flutter_test/flutter_test.dart';
import 'package:kos_manage_mobile/domain/services/rental_countdown.dart';

void main() {
  final reference = DateTime(2026, 10, 1, 12);

  group('rentalCountdownBucket', () {
    test('returns normal above 30 days', () {
      expect(
        rentalCountdownBucket(
          reference.add(const Duration(days: 31)),
          now: reference,
        ),
        RentalCountdownBucket.normal,
      );
    });

    test('returns attention at 15–30 days', () {
      expect(
        rentalCountdownBucket(
          reference.add(const Duration(days: 20)),
          now: reference,
        ),
        RentalCountdownBucket.attention,
      );
    });

    test('returns soon at 7–14 days', () {
      expect(
        rentalCountdownBucket(
          reference.add(const Duration(days: 10)),
          now: reference,
        ),
        RentalCountdownBucket.soon,
      );
    });

    test('returns verySoon at 1–6 days', () {
      expect(
        rentalCountdownBucket(
          reference.add(const Duration(days: 4)),
          now: reference,
        ),
        RentalCountdownBucket.verySoon,
      );
    });

    test('returns expired on the exact end date', () {
      expect(
        rentalCountdownBucket(reference, now: reference),
        RentalCountdownBucket.expired,
      );
    });

    test('returns pastDue below zero days', () {
      expect(
        rentalCountdownBucket(
          reference.subtract(const Duration(days: 2)),
          now: reference,
        ),
        RentalCountdownBucket.pastDue,
      );
    });
  });
}
