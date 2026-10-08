enum RentalDuration {
  day,
  week,
  month,
  year,
  custom,
}

String rentalDurationLabel(RentalDuration duration) {
  switch (duration) {
    case RentalDuration.day:
      return '1 Hari';
    case RentalDuration.week:
      return '1 Minggu';
    case RentalDuration.month:
      return '1 Bulan';
    case RentalDuration.year:
      return '1 Tahun';
    case RentalDuration.custom:
      return 'Custom';
  }
}

DateTime calculateRentalEndDate({
  required DateTime startDate,
  required RentalDuration duration,
  DateTime? customEndDate,
}) {
  final start = DateTime(startDate.year, startDate.month, startDate.day);

  switch (duration) {
    case RentalDuration.day:
      return start.add(const Duration(days: 1));
    case RentalDuration.week:
      return start.add(const Duration(days: 7));
    case RentalDuration.month:
      return _addMonthsClamped(start, 1);
    case RentalDuration.year:
      return _addMonthsClamped(start, 12);
    case RentalDuration.custom:
      if (customEndDate == null) {
        throw ArgumentError('Tanggal berakhir untuk sewa custom wajib diisi.');
      }
      final end = DateTime(
        customEndDate.year,
        customEndDate.month,
        customEndDate.day,
      );
      if (!end.isAfter(start)) {
        throw ArgumentError(
          'Tanggal berakhir harus setelah tanggal mulai.',
        );
      }
      return end;
  }
}

String? rentalDurationValidationMessage({
  required RentalDuration? duration,
  required DateTime startDate,
  DateTime? customEndDate,
}) {
  if (duration == null) {
    return 'Pilih durasi sewa.';
  }

  if (duration == RentalDuration.custom) {
    if (customEndDate == null) {
      return 'Pilih tanggal berakhir untuk sewa custom.';
    }
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(
      customEndDate.year,
      customEndDate.month,
      customEndDate.day,
    );
    if (!end.isAfter(start)) {
      return 'Tanggal berakhir harus setelah tanggal mulai.';
    }
  }

  return null;
}

DateTime _addMonthsClamped(DateTime value, int months) {
  final targetMonthIndex = value.year * 12 + (value.month - 1) + months;
  final targetYear = targetMonthIndex ~/ 12;
  final targetMonth = targetMonthIndex % 12 + 1;
  final lastDay = DateTime(targetYear, targetMonth + 1, 0).day;
  final day = value.day > lastDay ? lastDay : value.day;
  return DateTime(targetYear, targetMonth, day);
}
