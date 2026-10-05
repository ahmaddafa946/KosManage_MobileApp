import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/owner_management.dart';

class MyTenant {
  const MyTenant({required this.tenant, required this.propertyId});

  final OwnerTenant tenant;
  final String propertyId;
}

abstract interface class TenantRepository {
  Future<MyTenant> getMyTenantByEmail(String email);
  Future<List<OwnerPayment>> getMyPayments(String propertyId, String tenantId);
  Future<List<OwnerMaintenanceReport>> getMyReports(String tenantId);
  Future<void> createReport({
    required String propertyId,
    required String tenantId,
    required String? roomId,
    required String title,
    required String description,
    required String category,
    required String priority,
    File? photo,
  });
}

class SupabaseTenantRepository implements TenantRepository {
  SupabaseTenantRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<MyTenant> getMyTenantByEmail(String email) async {
    final clean = email.trim();
    if (clean.isEmpty) {
      throw StateError('Email akun tidak tersedia.');
    }
    final row = await _client
        .from('tenants')
        .select(
          '*, room:rooms!tenants_room_id_fkey(id,room_number,status,price)',
        )
        .ilike('email', clean)
        .eq('status', 'active')
        .limit(1)
        .maybeSingle();

    if (row == null) {
      throw StateError(
        'Data penghuni untuk akun ini belum terdaftar. Hubungi pemilik kos.',
      );
    }
    final propertyId = row['property_id'] as String?;
    if (propertyId == null) {
      throw StateError('Data properti penghuni tidak lengkap.');
    }
    return MyTenant(
      tenant: OwnerTenant.fromJson(row),
      propertyId: propertyId,
    );
  }

  @override
  Future<List<OwnerPayment>> getMyPayments(
    String propertyId,
    String tenantId,
  ) async {
    final rows = await _client
        .from('payments')
        .select(
          '*, tenant:tenants!payments_tenant_id_fkey(id,name), '
          'room:rooms!payments_room_id_fkey(id,room_number)',
        )
        .eq('property_id', propertyId)
        .eq('tenant_id', tenantId)
        .order('due_date', ascending: false)
        .limit(50);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(OwnerPayment.fromJson)
        .toList(growable: false);
  }

  @override
  Future<List<OwnerMaintenanceReport>> getMyReports(String tenantId) async {
    final rows = await _client
        .from('maintenance_reports')
        .select(
          '*, room:rooms!maintenance_reports_room_id_fkey(id,room_number), '
          'tenant:tenants!maintenance_reports_tenant_id_fkey(id,name)',
        )
        .eq('tenant_id', tenantId)
        .order('created_at', ascending: false)
        .limit(50);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(OwnerMaintenanceReport.fromJson)
        .toList(growable: false);
  }

  @override
  Future<void> createReport({
    required String propertyId,
    required String tenantId,
    required String? roomId,
    required String title,
    required String description,
    required String category,
    required String priority,
    File? photo,
  }) async {
    String? imagePath;
    if (photo != null) {
      final name = photo.path.split(Platform.pathSeparator).last;
      final clean = name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
      final path =
          '$propertyId/$tenantId/${DateTime.now().millisecondsSinceEpoch}_$clean';
      await _client.storage.from('maintenance-reports').upload(
            path,
            photo,
            fileOptions: const FileOptions(upsert: true),
          );
      imagePath = path;
    }

    final payload = <String, dynamic>{
      'property_id': propertyId,
      'tenant_id': tenantId,
      'room_id': roomId,
      'title': title.trim(),
      'description': description.trim(),
      'category': category,
      'priority': priority,
      'status': 'submitted',
      'image_url': imagePath,
    };
    payload.removeWhere((key, value) => value == null);

    await _client.from('maintenance_reports').insert(payload);
  }
}
