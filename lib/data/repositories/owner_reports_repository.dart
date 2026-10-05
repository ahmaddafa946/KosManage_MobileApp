import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/owner_management.dart';
import '../../domain/services/owner_report_calculator.dart';

abstract interface class OwnerReportsRepository {
  Future<List<OwnerMaintenanceReport>> getMaintenanceReports(
    String propertyId, {
    String status = 'all',
  });

  Future<void> updateMaintenanceStatus(String reportId, String status);

  Future<OwnerFinancialReport> getFinancialReport(
    String propertyId, {
    required int months,
  });

  Future<OwnerOperationalReport> getOperationalReport(String propertyId);
}

class OwnerFinancialReport {
  const OwnerFinancialReport({
    required this.summary,
    required this.months,
    required this.monthly,
  });

  final FinancialSummary summary;
  final int months;
  final List<MonthlyFinancialRow> monthly;
}

class MonthlyFinancialRow {
  const MonthlyFinancialRow({
    required this.period,
    required this.amountDue,
    required this.amountPaid,
    required this.outstanding,
  });

  final String period;
  final num amountDue;
  final num amountPaid;
  final num outstanding;
}

class OwnerOperationalReport {
  const OwnerOperationalReport({
    required this.totalRooms,
    required this.occupiedRooms,
    required this.availableRooms,
    required this.maintenanceRooms,
    required this.activeMaintenance,
  });

  final int totalRooms;
  final int occupiedRooms;
  final int availableRooms;
  final int maintenanceRooms;
  final List<OwnerMaintenanceReport> activeMaintenance;

  int get occupancyRate =>
      totalRooms == 0 ? 0 : ((occupiedRooms / totalRooms) * 100).round();
}

class SupabaseOwnerReportsRepository implements OwnerReportsRepository {
  SupabaseOwnerReportsRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<OwnerMaintenanceReport>> getMaintenanceReports(
    String propertyId, {
    String status = 'all',
  }) async {
    var request = _client
        .from('maintenance_reports')
        .select(
          '*, room:rooms!maintenance_reports_room_id_fkey(id,room_number), '
          'tenant:tenants!maintenance_reports_tenant_id_fkey(id,name)',
        )
        .eq('property_id', propertyId);

    if (status != 'all') {
      request = request.eq('status', status);
    }

    final rows = await request.order('created_at', ascending: false);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(OwnerMaintenanceReport.fromJson)
        .toList(growable: false);
  }

  @override
  Future<void> updateMaintenanceStatus(String reportId, String status) async {
    await _client
        .from('maintenance_reports')
        .update({'status': status})
        .eq('id', reportId);
  }

  @override
  Future<OwnerFinancialReport> getFinancialReport(
    String propertyId, {
    required int months,
  }) async {
    final now = DateTime.now();
    final first = DateTime(now.year, now.month - (months - 1), 1);
    String yyyymm(DateTime value) {
      return '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}';
    }

    final startPeriod = yyyymm(first);
    final nextMonth = DateTime(now.year, now.month + 1, 1);
    final endPeriod = yyyymm(nextMonth);

    final rows = await _client
        .from('payments')
        .select('billing_period,amount_due,amount_paid')
        .eq('property_id', propertyId)
        .gte('billing_period', startPeriod)
        .lt('billing_period', endPeriod)
        .order('billing_period', ascending: true);

    final entries = (rows as List).cast<Map<String, dynamic>>().map(
      (row) => FinancialPaymentEntry(
        billingPeriod: row['billing_period'] as String? ?? startPeriod,
        amountDue: row['amount_due'] as num? ?? 0,
        amountPaid: row['amount_paid'] as num? ?? 0,
      ),
    );

    final grouped = <String, List<FinancialPaymentEntry>>{};
    for (final entry in entries) {
      (grouped[entry.billingPeriod] ??= []).add(entry);
    }

    final monthly = grouped.entries.map((entry) {
      final summary = calculateFinancialSummary(entry.value);
      return MonthlyFinancialRow(
        period: entry.key,
        amountDue: summary.totalBill,
        amountPaid: summary.totalPaid,
        outstanding: summary.outstanding,
      );
    }).toList()..sort((a, b) => a.period.compareTo(b.period));

    final allEntries = <FinancialPaymentEntry>[];
    for (final rows in grouped.values) {
      allEntries.addAll(rows);
    }

    return OwnerFinancialReport(
      summary: calculateFinancialSummary(allEntries),
      months: months,
      monthly: monthly,
    );
  }

  @override
  Future<OwnerOperationalReport> getOperationalReport(String propertyId) async {
    final rooms = await _client
        .from('rooms')
        .select('id,status')
        .eq('property_id', propertyId);

    final maintenance = await getMaintenanceReports(propertyId);
    final roomRows = (rooms as List).cast<Map<String, dynamic>>();

    int count(String status) =>
        roomRows.where((row) => row['status'] == status).length;

    return OwnerOperationalReport(
      totalRooms: roomRows.length,
      occupiedRooms: count('occupied'),
      availableRooms: count('available'),
      maintenanceRooms: count('maintenance'),
      activeMaintenance: maintenance
          .where(
            (item) =>
                item.status == 'submitted' || item.status == 'in_progress',
          )
          .take(10)
          .toList(growable: false),
    );
  }
}
