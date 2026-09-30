import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/owner_dashboard_data.dart';
import '../../domain/services/dashboard_payment_rules.dart';

abstract interface class OwnerDashboardRepository {
  Future<OwnerDashboardData> load(String ownerId);
}

class SupabaseOwnerDashboardRepository implements OwnerDashboardRepository {
  SupabaseOwnerDashboardRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<OwnerDashboardData> load(String ownerId) async {
    final property = await _client
        .from('properties')
        .select('id,name')
        .eq('owner_id', ownerId)
        .order('created_at', ascending: true)
        .limit(1)
        .maybeSingle();

    if (property == null) {
      throw StateError('Property owner belum ditemukan.');
    }

    final propertyId = property['id'] as String;
    final propertyName = property['name'] as String? ?? 'Property';

    final rooms = await _client
        .from('rooms')
        .select('id,status')
        .eq('property_id', propertyId);

    final activeTenants = await _client
        .from('tenants')
        .select('id')
        .eq('property_id', propertyId)
        .eq('status', 'active')
        .count();

    final payments = await _client
        .from('payments')
        .select(
          'id,billing_period,due_date,amount_due,amount_paid,status,'
          'payment_date,created_at,tenants(name),rooms(room_number)',
        )
        .eq('property_id', propertyId)
        .order('created_at', ascending: false);

    final maintenance = await _client
        .from('maintenance_reports')
        .select(
          'id,title,priority,status,created_at,rooms(room_number)',
        )
        .eq('property_id', propertyId)
        .not('status', 'in', '(resolved,closed)')
        .order('created_at', ascending: false)
        .limit(5);

    final expiringTenants = await _client
        .from('tenants')
        .select('id,name,end_date,rooms(room_number)')
        .eq('property_id', propertyId)
        .eq('status', 'active')
        .gte(
          'end_date',
          DateTime.now().toIso8601String().substring(0, 10),
        )
        .lte(
          'end_date',
          DateTime.now()
              .add(const Duration(days: 30))
              .toIso8601String()
              .substring(0, 10),
        )
        .order('end_date', ascending: true)
        .limit(5);

    final parsedPayments = payments
        .map(PaymentPreview.fromJson)
        .toList(growable: false);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monthStart = DateTime(today.year, today.month);
    final nextMonth = DateTime(today.year, today.month + 1);

    num paidThisMonth = 0;
    num totalOutstanding = 0;

    for (final row in payments) {
      final paid = _num(row['amount_paid']);
      final due = _num(row['amount_due']);
      final paymentDate = DateTime.tryParse(
        row['payment_date'] as String? ?? '',
      );

      if (paymentDate != null &&
          !paymentDate.isBefore(monthStart) &&
          paymentDate.isBefore(nextMonth)) {
        paidThisMonth += paid;
      }

      final outstanding = due - paid;
      if (outstanding > 0) totalOutstanding += outstanding;
    }

    final recentPayments = parsedPayments.take(5).toList(growable: false);

    final upcomingPayments = parsedPayments.where((payment) {
      return isUpcomingPayment(
        payment.dueDate,
        today: today,
        remainingAmount: payment.remainingAmount,
      );
    }).toList()
      ..sort((a, b) => (a.dueDate ?? DateTime(9999)).compareTo(b.dueDate ?? DateTime(9999)));

    final overduePayments = parsedPayments.where((payment) {
      return isOverduePayment(
        payment.dueDate,
        today: today,
        remainingAmount: payment.remainingAmount,
        status: payment.status,
      );
    }).toList()
      ..sort((a, b) => (a.dueDate ?? DateTime(1970)).compareTo(b.dueDate ?? DateTime(1970)));

    final roomsByStatus = <String, int>{
      'occupied': 0,
      'available': 0,
      'maintenance': 0,
    };

    for (final room in rooms) {
      final status = room['status'] as String? ?? 'available';
      roomsByStatus[status] = (roomsByStatus[status] ?? 0) + 1;
    }

    return OwnerDashboardData(
      propertyId: propertyId,
      propertyName: propertyName,
      totalRooms: rooms.length,
      occupiedRooms: roomsByStatus['occupied'] ?? 0,
      availableRooms: roomsByStatus['available'] ?? 0,
      maintenanceRooms: roomsByStatus['maintenance'] ?? 0,
      activeTenants: activeTenants,
      paidThisMonth: paidThisMonth,
      totalOutstanding: totalOutstanding,
      recentPayments: recentPayments.take(5).toList(growable: false),
      upcomingPayments: upcomingPayments.take(5).toList(growable: false),
      overduePayments: overduePayments.take(5).toList(growable: false),
      activeMaintenance: maintenance
          .map(MaintenancePreview.fromJson)
          .toList(growable: false),
      expiringTenants: expiringTenants
          .map(ExpiringTenantPreview.fromJson)
          .toList(growable: false),
    );
  }
}

num _num(dynamic value) {
  if (value is num) return value;
  return num.tryParse(value?.toString() ?? '') ?? 0;
}
