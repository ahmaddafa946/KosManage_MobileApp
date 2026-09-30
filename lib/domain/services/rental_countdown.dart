enum RentalCountdownBucket {
  normal,
  attention,
  soon,
  verySoon,
  expired,
  pastDue,
}

RentalCountdownBucket rentalCountdownBucket(
  DateTime endDate, {
  required DateTime now,
}) {
  final today = DateTime(now.year, now.month, now.day);
  final end = DateTime(endDate.year, endDate.month, endDate.day);
  final daysRemaining = end.difference(today).inDays;

  if (daysRemaining > 30) return RentalCountdownBucket.normal;
  if (daysRemaining >= 15) return RentalCountdownBucket.attention;
  if (daysRemaining >= 7) return RentalCountdownBucket.soon;
  if (daysRemaining >= 1) return RentalCountdownBucket.verySoon;
  if (daysRemaining == 0) return RentalCountdownBucket.expired;
  return RentalCountdownBucket.pastDue;
}
