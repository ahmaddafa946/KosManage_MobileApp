class OwnerProperty {
  const OwnerProperty({required this.id, required this.name});

  final String id;
  final String name;
}

class OwnerRoom {
  const OwnerRoom({
    required this.id,
    required this.roomNumber,
    required this.price,
    required this.status,
    this.floor,
    this.facilities,
    this.notes,
    this.tenantName,
    this.tenantId,
  });

  final String id;
  final String roomNumber;
  final int? floor;
  final num price;
  final String status;
  final String? facilities;
  final String? notes;
  final String? tenantName;
  final String? tenantId;

  factory OwnerRoom.fromJson(Map<String, dynamic> json) {
    final value = json['active_tenant'];
    final tenant = value is Map ? Map<String, dynamic>.from(value) : null;
    return OwnerRoom(
      id: json['id'] as String,
      roomNumber: json['room_number'] as String? ?? '-',
      floor: (json['floor'] as num?)?.toInt(),
      price: json['price'] as num? ?? 0,
      status: json['status'] as String? ?? 'available',
      facilities: json['facilities'] as String?,
      notes: json['notes'] as String?,
      tenantName: tenant?['name'] as String?,
      tenantId: tenant?['id'] as String?,
    );
  }
}

class OwnerFacility {
  const OwnerFacility({
    required this.id,
    required this.name,
    required this.isActive,
  });

  final String id;
  final String name;
  final bool isActive;

  factory OwnerFacility.fromJson(Map<String, dynamic> json) {
    return OwnerFacility(
      id: json['id'] as String,
      name: json['name'] as String? ?? '-',
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

class OwnerTenant {
  const OwnerTenant({
    required this.id,
    required this.name,
    required this.status,
    required this.startDate,
    this.roomId,
    this.roomNumber,
    this.phone,
    this.email,
    this.identityNumber,
    this.endDate,
    this.rentPrice,
    this.deposit,
    this.notes,
  });

  final String id;
  final String name;
  final String status;
  final String startDate;
  final String? roomId;
  final String? roomNumber;
  final String? phone;
  final String? email;
  final String? identityNumber;
  final String? endDate;
  final num? rentPrice;
  final num? deposit;
  final String? notes;

  factory OwnerTenant.fromJson(Map<String, dynamic> json) {
    final value = json['room'];
    final room = value is Map ? Map<String, dynamic>.from(value) : null;
    return OwnerTenant(
      id: json['id'] as String,
      name: json['name'] as String? ?? '-',
      status: json['status'] as String? ?? 'active',
      startDate: json['start_date'] as String? ?? '',
      roomId: json['room_id'] as String?,
      roomNumber: room?['room_number'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      identityNumber: json['identity_number'] as String?,
      endDate: json['end_date'] as String?,
      rentPrice: json['rent_price'] as num?,
      deposit: json['deposit'] as num?,
      notes: json['notes'] as String?,
    );
  }
}

class OwnerPayment {
  const OwnerPayment({
    required this.id,
    required this.billingPeriod,
    required this.dueDate,
    required this.amountDue,
    required this.amountPaid,
    required this.status,
    this.tenantId,
    this.tenantName,
    this.roomNumber,
    this.paymentDate,
    this.paymentMethod,
    this.paymentReference,
    this.paymentUrl,
    this.paidAt,
    this.notes,
  });

  final String id;
  final String billingPeriod;
  final String dueDate;
  final num amountDue;
  final num amountPaid;
  final String status;
  final String? tenantId;
  final String? tenantName;
  final String? roomNumber;
  final String? paymentDate;
  final String? paymentMethod;
  final String? paymentReference;
  final String? paymentUrl;
  final String? paidAt;
  final String? notes;

  num get remaining {
    final value = amountDue - amountPaid;
    return value > 0 ? value : 0;
  }

  factory OwnerPayment.fromJson(Map<String, dynamic> json) {
    final tenantValue = json['tenant'];
    final roomValue = json['room'];
    final tenant = tenantValue is Map ? Map<String, dynamic>.from(tenantValue) : null;
    final room = roomValue is Map ? Map<String, dynamic>.from(roomValue) : null;
    return OwnerPayment(
      id: json['id'] as String,
      billingPeriod: json['billing_period'] as String? ?? '-',
      dueDate: json['due_date'] as String? ?? '',
      amountDue: json['amount_due'] as num? ?? 0,
      amountPaid: json['amount_paid'] as num? ?? 0,
      status: json['status'] as String? ?? 'unpaid',
      tenantId: json['tenant_id'] as String? ?? tenant?['id'] as String?,
      tenantName: tenant?['name'] as String?,
      roomNumber: room?['room_number'] as String?,
      paymentDate: json['payment_date'] as String?,
      paymentMethod: json['payment_method'] as String?,
      paymentReference: json['payment_reference'] as String?,
      paymentUrl: json['payment_url'] as String?,
      paidAt: json['paid_at'] as String?,
      notes: json['notes'] as String?,
    );
  }
}

class OwnerMaintenanceReport {
  const OwnerMaintenanceReport({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.priority,
    required this.status,
    required this.createdAt,
    this.roomNumber,
    this.tenantName,
    this.imageUrl,
  });

  final String id;
  final String title;
  final String description;
  final String category;
  final String priority;
  final String status;
  final String createdAt;
  final String? roomNumber;
  final String? tenantName;
  final String? imageUrl;

  factory OwnerMaintenanceReport.fromJson(Map<String, dynamic> json) {
    final roomValue = json['room'];
    final tenantValue = json['tenant'];
    final room = roomValue is Map ? Map<String, dynamic>.from(roomValue) : null;
    final tenant = tenantValue is Map ? Map<String, dynamic>.from(tenantValue) : null;
    return OwnerMaintenanceReport(
      id: json['id'] as String,
      title: json['title'] as String? ?? '-',
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? 'other',
      priority: json['priority'] as String? ?? 'medium',
      status: json['status'] as String? ?? 'submitted',
      createdAt: json['created_at'] as String? ?? '',
      roomNumber: room?['room_number'] as String?,
      tenantName: tenant?['name'] as String?,
      imageUrl: json['image_url'] as String?,
    );
  }
}
