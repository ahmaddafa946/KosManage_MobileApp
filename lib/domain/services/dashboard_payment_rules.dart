DateTime _day(DateTime value) => DateTime(value.year, value.month, value.day);

bool isUpcomingPayment(
  DateTime? dueDate, {
  required DateTime today,
  required num remainingAmount,
}) {
  if (dueDate == null || remainingAmount <= 0) return false;

  final currentDay = _day(today);
  final dueDay = _day(dueDate);
  final lastIncludedDay = currentDay.add(const Duration(days: 7));

  return !dueDay.isBefore(currentDay) && !dueDay.isAfter(lastIncludedDay);
}

bool isOverduePayment(
  DateTime? dueDate, {
  required DateTime today,
  required num remainingAmount,
  required String status,
}) {
  if (remainingAmount <= 0) return false;

  final currentDay = _day(today);
  final dueDay = dueDate == null ? null : _day(dueDate);

  return status == 'overdue' ||
      (dueDay != null && dueDay.isBefore(currentDay));
}
