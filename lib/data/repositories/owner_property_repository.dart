import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/owner_management.dart';

abstract interface class OwnerPropertyRepository {
  Future<OwnerProperty> getPrimaryProperty(String ownerId);
}

class SupabaseOwnerPropertyRepository implements OwnerPropertyRepository {
  SupabaseOwnerPropertyRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<OwnerProperty> getPrimaryProperty(String ownerId) async {
    final row = await _client
        .from('properties')
        .select('id,name')
        .eq('owner_id', ownerId)
        .order('created_at', ascending: true)
        .limit(1)
        .maybeSingle();

    if (row == null) throw StateError('Property owner belum ditemukan.');
    return OwnerProperty(
      id: row['id'] as String,
      name: row['name'] as String? ?? 'KosManage',
    );
  }
}
