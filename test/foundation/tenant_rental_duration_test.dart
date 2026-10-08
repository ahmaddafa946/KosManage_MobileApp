import 'package:flutter_test/flutter_test.dart';

import 'package:kos_manage_mobile/domain/services/rental_duration.dart';

void main() {
  group('calculateRentalEndDate', () {
    test('1 hari adds one calendar day', () {
      final end = calculateRentalEndDate(
        startDate: DateTime(2026, 10, 8),
        duration: RentalDuration.day,
      );

      expect(end, DateTime(2026, 10, 9));
    });

    test('1 minggu adds seven calendar days', () {
      final end = calculateRentalEndDate(
        startDate: DateTime(2026, 10, 8),
        duration: RentalDuration.week,
      );

      expect(end, DateTime(2026, 10, 15));
    });

    test('1 bulan advances one calendar month', () {
      final end = calculateRentalEndDate(
        startDate: DateTime(2026, 10, 8),
        duration: RentalDuration.month,
      );

      expect(end, DateTime(2026, 11, 8));
    });

    test('1 bulan clamps month-end dates instead of overflowing', () {
      final end = calculateRentalEndDate(
        startDate: DateTime(2026, 1, 31),
        duration: RentalDuration.month,
      );

      expect(end, DateTime(2026, 2, 28));
    });

    test('1 tahun advances one calendar year', () {
      final end = calculateRentalEndDate(
        startDate: DateTime(2026, 10, 8),
        duration: RentalDuration.year,
      );

      expect(end, DateTime(2027, 10, 8));
    });

    test('1 tahun clamps leap-day dates in non-leap years', () {
      final end = calculateRentalEndDate(
        startDate: DateTime(2028, 2, 29),
        duration: RentalDuration.year,
      );

      expect(end, DateTime(2029, 2, 28));
    });

    test('custom duration uses the explicitly selected end date', () {
      final end = calculateRentalEndDate(
        startDate: DateTime(2026, 10, 8),
        duration: RentalDuration.custom,
        customEndDate: DateTime(2026, 12, 20),
      );

      expect(end, DateTime(2026, 12, 20));
    });

    test('custom duration rejects an end date on or before the start date', () {
      expect(
        () => calculateRentalEndDate(
          startDate: DateTime(2026, 10, 8),
          duration: RentalDuration.custom,
          customEndDate: DateTime(2026, 10, 8),
        ),
        throwsArgumentError,
      );
    });

    test('custom duration requires an end date', () {
      expect(
        () => calculateRentalEndDate(
          startDate: DateTime(2026, 10, 8),
          duration: RentalDuration.custom,
        ),
        throwsArgumentError,
      );
    });
  });

  test('duration selection is required before submitting the rental form', () {
    expect(
      rentalDurationValidationMessage(
        duration: null,
        startDate: DateTime(2026, 10, 8),
      ),
      'Pilih durasi sewa.',
    );
  });

  test('custom duration requires an end date after the start date', () {
    expect(
      rentalDurationValidationMessage(
        duration: RentalDuration.custom,
        startDate: DateTime(2026, 10, 8),
      ),
      'Pilih tanggal berakhir untuk sewa custom.',
    );

    expect(
      rentalDurationValidationMessage(
        duration: RentalDuration.custom,
        startDate: DateTime(2026, 10, 8),
        customEndDate: DateTime(2026, 10, 8),
      ),
      'Tanggal berakhir harus setelah tanggal mulai.',
    );
  });
}
