class OwnerDashboardData {
  const OwnerDashboardData({
    required this.propertyId,
    required this.propertyName,
    required this.totalRooms,
    required this.occupiedRooms,
    required this.availableRooms,
    required this.maintenanceRooms,
    required this.activeTenants,
    required this.paidThisMonth,
    required this.totalOutstanding,
    required this.recentPayments,
    required this.upcomingPayments,
    required this.overduePayments,
    required this.activeMaintenance,
    required this.expiringTenants,
  });

  final String propertyId;
  final String propertyName;
  final int totalRooms;
  final int occupiedRooms;
  final int availableRooms;
  final int maintenanceRooms;
  final int activeTenants;
  final num paidThisMonth;
  final num totalOutstanding;
  final List<PaymentPreview> recentPayments;
  final List<PaymentPreview> upcomingPayments;
  final List<PaymentPreview> overduePayments;
  final List<MaintenancePreview> activeMaintenance;
  final List<ExpiringTenantPreview> expiringTenants;

  factory OwnerDashboardData.fromSummaryJson(Map<String, dynamic> json) {
    return OwnerDashboardData(
      propertyId: json['property_id'] as String? ?? '',
      propertyName: json['property_name'] as String? ?? 'Property',
      totalRooms: _asInt(json['rooms']),
      occupiedRooms: _asInt(json['occupied_rooms']),
      availableRooms: _asInt(json['available_rooms']),
      maintenanceRooms: _asInt(json['maintenance_rooms']),
      activeTenants: _asInt(json['active_tenants']),
      paidThisMonth: _asNum(json['paid_this_month']),
      totalOutstanding: _asNum(json['total_outstanding']),
      recentPayments: const [],
      upcomingPayments: const [],
      overduePayments: const [],
      activeMaintenance: const [],
      expiringTenants: const [],
    );
  }
}

class PaymentPreview {
  const PaymentPreview({
    required this.id,
    required this.tenantName,
    required this.roomNumber,
    required this.billingPeriod,
    required this.dueDate,
    required this.amountDue,
    required this.amountPaid,
    required this.status,
  });

  final String id;
  final String tenantName;
  final String roomNumber;
  final String billingPeriod;
  final DateTime? dueDate;
  final num amountDue;
  final num amountPaid;
  final String status;

  num get remainingAmount => amountDue - amountPaid;

  factory PaymentPreview.fromJson(Map<String, dynamic> json) {
    return PaymentPreview(
      id: json['id'] as String? ?? '',
      tenantName: _nestedText(json['tenants'], 'name'),
      roomNumber: _nestedText(json['rooms'], 'room_number'),
      billingPeriod: json['billing_period'] as String? ?? '-',
      dueDate: DateTime.tryParse(json['due_date'] as String? ?? ''),
      amountDue: _asNum(json['amount_due']),
      amountPaid: _asNum(json['amount_paid']),
      status: json['status'] as String? ?? 'unpaid',
    );
  }
}

class MaintenancePreview {
  const MaintenancePreview({
    required this.id,
    required this.title,
    required this.roomNumber,
    required this.priority,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String roomNumber;
  final String priority;
  final String status;
  final DateTime? createdAt;

  factory MaintenancePreview.fromJson(Map<String, dynamic> json) {
    return MaintenancePreview(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Laporan maintenance',
      roomNumber: _nestedText(json['rooms'], 'room_number'),
      priority: json['priority'] as String? ?? 'medium',
      status: json['status'] as String? ?? 'submitted',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
    );
  }
}

class ExpiringTenantPreview {
  const ExpiringTenantPreview({
    required this.id,
    required this.name,
    required this.roomNumber,
    required this.endDate,
  });

  final String id;
  final String name;
  final String roomNumber;
  final DateTime? endDate;

  factory ExpiringTenantPreview.fromJson(Map<String, dynamic> json) {
    return ExpiringTenantPreview(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Penghuni',
      roomNumber: _nestedText(json['rooms'], 'room_number'),
      endDate: DateTime.tryParse(json['end_date'] as String? ?? ''),
    );
  }
}

int _asInt(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

num _asNum(dynamic value) {
  if (value is num) return value;
  return num.tryParse(value?.toString() ?? '') ?? 0;
}

String _nestedText(dynamic value, String key) {
  if (value is Map<String, dynamic>) {
    return value[key] as String? ?? '-';
  }
  if (value is List &&
      value.isNotEmpty &&
      value.first is Map<String, dynamic>) {
    return (value.first as Map<String, dynamic>)[key] as String? ?? '-';
  }
  return '-';
}
