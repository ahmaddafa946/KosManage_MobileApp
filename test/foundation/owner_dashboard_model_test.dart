import 'package:flutter_test/flutter_test.dart';
import 'package:kos_manage_mobile/domain/models/owner_dashboard_data.dart';

void main() {
  test('builds dashboard summary from Supabase scalar values', () {
    final data = OwnerDashboardData.fromSummaryJson({
      'property_id': 'property-1',
      'property_name': 'Kost Putra Tampan',
      'rooms': 100,
      'occupied_rooms': 98,
      'available_rooms': 1,
      'maintenance_rooms': 1,
      'active_tenants': 98,
      'paid_this_month': '60007500.00',
      'total_outstanding': '82692500.00',
    });

    expect(data.propertyName, 'Kost Putra Tampan');
    expect(data.totalRooms, 100);
    expect(data.occupiedRooms, 98);
    expect(data.availableRooms, 1);
    expect(data.maintenanceRooms, 1);
    expect(data.activeTenants, 98);
    expect(data.paidThisMonth, 60007500);
    expect(data.totalOutstanding, 82692500);
  });

  test('parses recent payment and maintenance previews', () {
    final payment = PaymentPreview.fromJson({
      'id': 'payment-1',
      'tenants': {'name': 'Budi'},
      'rooms': {'room_number': 'A-01'},
      'billing_period': '2026-10',
      'due_date': '2026-10-25',
      'amount_due': '1400000',
      'amount_paid': '1400000',
      'status': 'paid',
    });
    final maintenance = MaintenancePreview.fromJson({
      'id': 'report-1',
      'title': 'AC kurang dingin',
      'rooms': {'room_number': 'A-02'},
      'priority': 'high',
      'status': 'in_progress',
      'created_at': '2026-10-01T00:00:00Z',
    });

    expect(payment.tenantName, 'Budi');
    expect(payment.amountPaid, 1400000);
    expect(payment.status, 'paid');
    expect(maintenance.title, 'AC kurang dingin');
    expect(maintenance.roomNumber, 'A-02');
    expect(maintenance.priority, 'high');
  });
}
