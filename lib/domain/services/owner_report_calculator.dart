class FinancialPaymentEntry {
  const FinancialPaymentEntry({
    required this.billingPeriod,
    required this.amountDue,
    required this.amountPaid,
  });

  final String billingPeriod;
  final num amountDue;
  final num amountPaid;
}

class FinancialSummary {
  const FinancialSummary({
    required this.totalBill,
    required this.totalPaid,
    required this.outstanding,
  });

  final num totalBill;
  final num totalPaid;
  final num outstanding;

  double get paidRatio => totalBill <= 0 ? 0 : totalPaid / totalBill;
}

FinancialSummary calculateFinancialSummary(
  Iterable<FinancialPaymentEntry> entries,
) {
  num totalBill = 0;
  num totalPaid = 0;
  num outstanding = 0;
  for (final entry in entries) {
    totalBill += entry.amountDue;
    totalPaid += entry.amountPaid;
    final remaining = entry.amountDue - entry.amountPaid;
    if (remaining > 0) outstanding += remaining;
  }
  return FinancialSummary(
    totalBill: totalBill,
    totalPaid: totalPaid,
    outstanding: outstanding,
  );
}
