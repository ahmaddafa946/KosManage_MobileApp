import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors/app_exception.dart';
import '../../domain/models/user_profile.dart';

abstract interface class ProfileRepository {
  Future<UserProfile> getCurrentProfile(String userId);
}

class SupabaseProfileRepository implements ProfileRepository {
  SupabaseProfileRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<UserProfile> getCurrentProfile(String userId) async {
    if (userId.isEmpty) {
      throw const SessionException();
    }
    try {
      final response = await _client
          .from('profiles')
          .select('id,full_name,role,email')
          .eq('id', userId)
          .maybeSingle();

      if (response == null) {
        // ponytail: id-based lookup only; wire tenants.profile_id next
        // when tenant accounts actually exist.
        throw const NotFoundException(
          'Profil akun tidak ditemukan. Hubungi pemilik kos atau daftar ulang.',
        );
      }

      return UserProfile.fromJson(response);
    } on PostgrestException {
      throw const AuthorizationException(
        'Akses profil ditolak. Periksa koneksi dan izin akun.',
      );
    } on FormatException {
      throw const ValidationException(
        'Data profil tidak lengkap. Hubungi pemilik kos.',
      );
    }
  }
}
