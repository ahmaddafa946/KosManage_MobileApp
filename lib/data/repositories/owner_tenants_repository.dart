import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/owner_management.dart';

abstract interface class OwnerTenantsRepository {
  Future<List<OwnerTenant>> getTenants(
    String propertyId, {
    String query = '',
    String status = 'all',
  });

  Future<List<OwnerRoom>> getAvailableRooms(
    String propertyId, {
    String? currentRoomId,
  });

  Future<OwnerTenant> createTenant(
    String propertyId, {
    required String name,
    required String? roomId,
    required String phone,
    required String email,
    required String identityNumber,
    required String startDate,
    required String endDate,
    required num rentPrice,
    required num deposit,
    required String notes,
  });

  Future<OwnerTenant> updateTenant(
    String tenantId, {
    required String name,
    required String? roomId,
    required String phone,
    required String email,
    required String identityNumber,
    required String startDate,
    required String endDate,
    required num rentPrice,
    required num deposit,
    required String notes,
  });

  Future<OwnerTenant> deactivateTenant(
    String tenantId, {
    required String endDate,
  });

  Future<void> deleteTenant(String tenantId);
}

class SupabaseOwnerTenantsRepository implements OwnerTenantsRepository {
  SupabaseOwnerTenantsRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<OwnerTenant>> getTenants(
    String propertyId, {
    String query = '',
    String status = 'all',
  }) async {
    var request = _client
        .from('tenants')
        .select(
          '*, room:rooms!tenants_room_id_fkey(id,room_number,status,price)',
        )
        .eq('property_id', propertyId);

    if (status != 'all') {
      request = request.eq('status', status);
    }
    if (query.trim().isNotEmpty) {
      final value = query.trim();
      request = request.or(
        'name.ilike.%$value%,phone.ilike.%$value%',
      );
    }

    final rows = await request.order('name');
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(OwnerTenant.fromJson)
        .toList(growable: false);
  }

  @override
  Future<List<OwnerRoom>> getAvailableRooms(
    String propertyId, {
    String? currentRoomId,
  }) async {
    final rows = await _client
        .from('rooms')
        .select('id,room_number,floor,price,status,facilities,notes')
        .eq('property_id', propertyId)
        .order('room_number');

    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(OwnerRoom.fromJson)
        .where((room) => room.status == 'available' || room.id == currentRoomId)
        .toList(growable: false);
  }

  Future<OwnerTenant> _reloadTenant(String tenantId) async {
    final row = await _client
        .from('tenants')
        .select(
          '*, room:rooms!tenants_room_id_fkey(id,room_number,status,price)',
        )
        .eq('id', tenantId)
        .single();
    return OwnerTenant.fromJson(row);
  }

  @override
  Future<OwnerTenant> createTenant(
    String propertyId, {
    required String name,
    required String? roomId,
    required String phone,
    required String email,
    required String identityNumber,
    required String startDate,
    required String endDate,
    required num rentPrice,
    required num deposit,
    required String notes,
  }) async {
    final row = await _client
        .from('tenants')
        .insert({
          'property_id': propertyId,
          'room_id': roomId,
          'name': name.trim(),
          'phone': phone.trim().isEmpty ? null : phone.trim(),
          'email': email.trim().isEmpty ? null : email.trim(),
          'identity_number': identityNumber.trim().isEmpty
              ? null
              : identityNumber.trim(),
          'start_date': startDate,
          'end_date': endDate.isEmpty ? null : endDate,
          'rent_price': rentPrice,
          'deposit': deposit == 0 ? null : deposit,
          'status': 'active',
          'notes': notes.trim().isEmpty ? null : notes.trim(),
        })
        .select()
        .single();

    return _reloadTenant(row['id'] as String);
  }

  @override
  Future<OwnerTenant> updateTenant(
    String tenantId, {
    required String name,
    required String? roomId,
    required String phone,
    required String email,
    required String identityNumber,
    required String startDate,
    required String endDate,
    required num rentPrice,
    required num deposit,
    required String notes,
  }) async {
    await _client
        .from('tenants')
        .update({
          'name': name.trim(),
          'room_id': roomId,
          'phone': phone.trim().isEmpty ? null : phone.trim(),
          'email': email.trim().isEmpty ? null : email.trim(),
          'identity_number': identityNumber.trim().isEmpty
              ? null
              : identityNumber.trim(),
          'start_date': startDate,
          'end_date': endDate.isEmpty ? null : endDate,
          'rent_price': rentPrice,
          'deposit': deposit == 0 ? null : deposit,
          'notes': notes.trim().isEmpty ? null : notes.trim(),
        })
        .eq('id', tenantId)
        .select()
        .single();

    return _reloadTenant(tenantId);
  }

  @override
  Future<OwnerTenant> deactivateTenant(
    String tenantId, {
    required String endDate,
  }) async {
    await _client
        .from('tenants')
        .update({'status': 'inactive', 'end_date': endDate})
        .eq('id', tenantId)
        .select()
        .single();

    return _reloadTenant(tenantId);
  }

  @override
  Future<void> deleteTenant(String tenantId) async {
    await _client.from('tenants').delete().eq('id', tenantId);
  }
}
