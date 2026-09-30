import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/user_profile.dart';

abstract interface class ProfileRepository {
  Future<UserProfile> getCurrentProfile(String userId);
}

class SupabaseProfileRepository implements ProfileRepository {
  SupabaseProfileRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<UserProfile> getCurrentProfile(String userId) async {
    final response = await _client
        .from('profiles')
        .select('id,name,role,email')
        .eq('id', userId)
        .maybeSingle();

    if (response == null) {
      throw StateError('Profile tidak ditemukan untuk user $userId.');
    }

    return UserProfile.fromJson(response);
  }
}
