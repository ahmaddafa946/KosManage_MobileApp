import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors/app_exception.dart';
import '../../domain/models/owner_management.dart';

class MyTenant {
  const MyTenant({required this.tenant, required this.propertyId});

  final OwnerTenant tenant;
  final String propertyId;
}

abstract interface class TenantRepository {
  Future<MyTenant> getMyTenant(String profileId);
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
  Future<Map<String, dynamic>> createPaymentIntent({
    required String invoiceId,
    required String paymentMethod,
    String? bank,
  });
  Future<Map<String, dynamic>> createCashPayment({
    required String invoiceId,
  });
}

class SupabaseTenantRepository implements TenantRepository {
  SupabaseTenantRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<MyTenant> getMyTenant(String profileId) async {
    final clean = profileId.trim();
    if (clean.isEmpty) {
      throw const SessionException();
    }
    final row = await _client
        .from('tenants')
        .select(
          '*, room:rooms!tenants_room_id_fkey(id,room_number,status,price)',
        )
        .eq('profile_id', clean)
        .eq('status', 'active')
        .limit(1)
        .maybeSingle();

    if (row == null) {
      throw const NotFoundException(
        'Data penghuni untuk akun ini belum terdaftar. Hubungi pemilik kos.',
      );
    }
    return _toMyTenant(row);
  }

  @override
  Future<MyTenant> getMyTenantByEmail(String email) async {
    // ponytail: legacy email fallback until tenants.profile_id is linked.
    final clean = email.trim();
    if (clean.isEmpty) {
      throw const SessionException();
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
      throw const NotFoundException(
        'Data penghuni untuk akun ini belum terdaftar. Hubungi pemilik kos.',
      );
    }
    return _toMyTenant(row);
  }

  MyTenant _toMyTenant(Map<String, dynamic> row) {
    final propertyId = row['property_id'] as String?;
    if (propertyId == null) {
      throw const ValidationException(
        'Data properti penghuni tidak lengkap.',
      );
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
    final reportRow = await _client
        .from('maintenance_reports')
        .insert({
          'property_id': propertyId,
          'tenant_id': tenantId,
          'room_id': roomId,
          'title': title.trim(),
          'description': description.trim(),
          'category': category,
          'priority': priority,
          'status': 'submitted',
        })
        .select('id')
        .single();
    final reportId = reportRow['id'] as String;

    if (photo != null) {
      final name = photo.path.split(Platform.pathSeparator).last;
      final clean = name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
      // Storage policy requires property/tenant/report 3-segment path.
      final path =
          '$propertyId/$tenantId/$reportId/${DateTime.now().millisecondsSinceEpoch}_$clean';
      await _client.storage.from('maintenance-reports').upload(
            path,
            photo,
            fileOptions: const FileOptions(upsert: true),
          );
      await _client
          .from('maintenance_reports')
          .update({'image_url': path})
          .eq('id', reportId);
    }
  }

  @override
  Future<Map<String, dynamic>> createPaymentIntent({
    required String invoiceId,
    required String paymentMethod,
    String? bank,
  }) async {
    final response = await _client.functions.invoke(
      'create-payment',
      body: {
        'invoice_id': invoiceId,
        'payment_method': paymentMethod,
        'bank': bank,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> createCashPayment({
    required String invoiceId,
  }) async {
    final response = await _client.functions.invoke(
      'cash-payment',
      body: {
        'invoice_id': invoiceId,
      },
    );
    return response.data as Map<String, dynamic>;
  }
}
