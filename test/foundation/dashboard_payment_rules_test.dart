import 'package:flutter_test/flutter_test.dart';
import 'package:kos_manage_mobile/domain/services/dashboard_payment_rules.dart';

void main() {
  final today = DateTime(2026, 10, 1, 15);

  test('treats a payment due today as upcoming, not overdue', () {
    final dueToday = DateTime(2026, 10, 1);

    expect(
      isUpcomingPayment(dueToday, today: today, remainingAmount: 100),
      isTrue,
    );
    expect(
      isOverduePayment(
        dueToday,
        today: today,
        remainingAmount: 100,
        status: 'unpaid',
      ),
      isFalse,
    );
  });

  test('treats payments due within seven days as upcoming', () {
    final due = DateTime(2026, 10, 7);

    expect(isUpcomingPayment(due, today: today, remainingAmount: 100), isTrue);
  });

  test('treats a past unpaid payment as overdue', () {
    final due = DateTime(2026, 9, 30);

    expect(isUpcomingPayment(due, today: today, remainingAmount: 100), isFalse);
    expect(
      isOverduePayment(
        due,
        today: today,
        remainingAmount: 100,
        status: 'unpaid',
      ),
      isTrue,
    );
  });

  test('paid payments are never marked overdue', () {
    final due = DateTime(2026, 9, 30);

    expect(
      isOverduePayment(due, today: today, remainingAmount: 0, status: 'paid'),
      isFalse,
    );
  });
}
