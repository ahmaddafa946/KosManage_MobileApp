import 'package:flutter_test/flutter_test.dart';

import 'package:kosmanage_mobile_app/domain/services/owner_report_calculator.dart';

void main() {
  test('calculates financial summary from payment rows', () {
    final summary = calculateFinancialSummary([
      const FinancialPaymentEntry(
        billingPeriod: '2026-09',
        amountDue: 1500000,
        amountPaid: 1500000,
      ),
      const FinancialPaymentEntry(
        billingPeriod: '2026-09',
        amountDue: 2000000,
        amountPaid: 1000000,
      ),
      const FinancialPaymentEntry(
        billingPeriod: '2026-10',
        amountDue: 1800000,
        amountPaid: 0,
      ),
    ]);

    expect(summary.totalBill, 5300000);
    expect(summary.totalPaid, 2500000);
    expect(summary.outstanding, 2800000);
    expect(summary.paidRatio, closeTo(2500000 / 5300000, 0.000001));
  });

  test('normalizes overpayment into zero outstanding', () {
    final summary = calculateFinancialSummary([
      const FinancialPaymentEntry(
        billingPeriod: '2026-10',
        amountDue: 1000000,
        amountPaid: 1200000,
      ),
    ]);

    expect(summary.totalBill, 1000000);
    expect(summary.totalPaid, 1200000);
    expect(summary.outstanding, 0);
  });
}
