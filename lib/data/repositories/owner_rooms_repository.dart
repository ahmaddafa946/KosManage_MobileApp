import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/owner_management.dart';

abstract interface class OwnerRoomsRepository {
  Future<List<OwnerRoom>> getRooms(
    String propertyId, {
    String query = '',
    String status = 'all',
  });

  Future<List<OwnerFacility>> getFacilities(String propertyId);

  Future<List<String>> getRoomFacilityIds(String roomId);

  Future<OwnerRoom> createRoom(
    String propertyId, {
    required String roomNumber,
    required int? floor,
    required num price,
    required String status,
    required String? notes,
    required List<String> facilityIds,
  });

  Future<OwnerRoom> updateRoom(
    String roomId, {
    required String roomNumber,
    required int? floor,
    required num price,
    required String status,
    required String? notes,
    required List<String> facilityIds,
  });

  Future<void> deleteRoom(String roomId);

  Future<OwnerFacility> createFacility(String propertyId, String name);
}

class SupabaseOwnerRoomsRepository implements OwnerRoomsRepository {
  SupabaseOwnerRoomsRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<OwnerRoom>> getRooms(
    String propertyId, {
    String query = '',
    String status = 'all',
  }) async {
    var request = _client
        .from('rooms')
        .select(
          'id,property_id,room_number,floor,price,status,facilities,notes',
        )
        .eq('property_id', propertyId);

    if (query.trim().isNotEmpty) {
      request = request.ilike('room_number', '%${query.trim()}%');
    }
    if (status != 'all') {
      request = request.eq('status', status);
    }

    final roomRows = await request.order('room_number');
    final rooms = (roomRows as List)
        .cast<Map<String, dynamic>>()
        .map(OwnerRoom.fromJson)
        .toList(growable: false);

    final tenantRows = await _client
        .from('tenants')
        .select('id,name,room_id')
        .eq('property_id', propertyId)
        .eq('status', 'active');

    final tenantsByRoom = <String, Map<String, dynamic>>{};
    for (final tenant in (tenantRows as List).cast<Map<String, dynamic>>()) {
      final roomId = tenant['room_id'] as String?;
      if (roomId != null) tenantsByRoom[roomId] = tenant;
    }

    return rooms
        .map(
          (room) => room.copyWith(
            tenantId: tenantsByRoom[room.id]?['id'] as String?,
            tenantName: tenantsByRoom[room.id]?['name'] as String?,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<List<OwnerFacility>> getFacilities(String propertyId) async {
    final rows = await _client
        .from('facilities')
        .select('id,name,is_active')
        .eq('property_id', propertyId)
        .eq('is_active', true)
        .order('name');

    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(OwnerFacility.fromJson)
        .toList(growable: false);
  }

  @override
  Future<List<String>> getRoomFacilityIds(String roomId) async {
    final rows = await _client
        .from('room_facilities')
        .select('facility_id')
        .eq('room_id', roomId);

    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map((row) => row['facility_id'] as String)
        .toList(growable: false);
  }

  Future<void> _syncFacilities(String roomId, List<String> targetIds) async {
    final current = await getRoomFacilityIds(roomId);
    final currentSet = current.toSet();
    final targetSet = targetIds.toSet();

    final remove = currentSet.difference(targetSet).toList();
    final add = targetSet.difference(currentSet).toList();

    if (remove.isNotEmpty) {
      await _client
          .from('room_facilities')
          .delete()
          .eq('room_id', roomId)
          .inFilter('facility_id', remove);
    }

    if (add.isNotEmpty) {
      await _client
          .from('room_facilities')
          .insert(
            add.map((id) => {'room_id': roomId, 'facility_id': id}).toList(),
          );
    }
  }

  Future<OwnerRoom> _reloadRoom(String roomId) async {
    final row = await _client
        .from('rooms')
        .select(
          'id,property_id,room_number,floor,price,status,facilities,notes',
        )
        .eq('id', roomId)
        .single();

    final room = OwnerRoom.fromJson(row);
    final tenant = await _client
        .from('tenants')
        .select('id,name')
        .eq('room_id', roomId)
        .eq('status', 'active')
        .maybeSingle();

    return room.copyWith(
      tenantId: tenant?['id'] as String?,
      tenantName: tenant?['name'] as String?,
    );
  }

  @override
  Future<OwnerRoom> createRoom(
    String propertyId, {
    required String roomNumber,
    required int? floor,
    required num price,
    required String status,
    required String? notes,
    required List<String> facilityIds,
  }) async {
    final row = await _client
        .from('rooms')
        .insert({
          'property_id': propertyId,
          'room_number': roomNumber.trim(),
          'floor': floor,
          'price': price,
          'status': status,
          'notes': notes?.trim().isEmpty == true ? null : notes?.trim(),
        })
        .select()
        .single();

    final roomId = row['id'] as String;
    if (facilityIds.isNotEmpty) {
      await _syncFacilities(roomId, facilityIds);
    }
    return _reloadRoom(roomId);
  }

  @override
  Future<OwnerRoom> updateRoom(
    String roomId, {
    required String roomNumber,
    required int? floor,
    required num price,
    required String status,
    required String? notes,
    required List<String> facilityIds,
  }) async {
    await _client
        .from('rooms')
        .update({
          'room_number': roomNumber.trim(),
          'floor': floor,
          'price': price,
          'status': status,
          'notes': notes?.trim().isEmpty == true ? null : notes?.trim(),
        })
        .eq('id', roomId)
        .select()
        .single();

    await _syncFacilities(roomId, facilityIds);
    return _reloadRoom(roomId);
  }

  @override
  Future<void> deleteRoom(String roomId) async {
    await _client.from('rooms').delete().eq('id', roomId);
  }

  @override
  Future<OwnerFacility> createFacility(String propertyId, String name) async {
    final clean = name.trim();
    if (clean.isEmpty) {
      throw StateError('Nama fasilitas wajib diisi.');
    }

    final row = await _client
        .from('facilities')
        .insert({'property_id': propertyId, 'name': clean})
        .select()
        .single();

    return OwnerFacility.fromJson(row);
  }
}
