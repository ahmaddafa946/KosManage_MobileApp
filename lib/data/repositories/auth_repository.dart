import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class AuthRepository {
  Session? get currentSession;

  Future<void> signIn({required String email, required String password});

  Future<void> signUp({
    required String fullName,
    required String email,
    required String password,
  });

  Future<void> signOut();
}

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  @override
  Session? get currentSession => _client.auth.currentSession;

  @override
  Future<void> signIn({required String email, required String password}) async {
    await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  @override
  Future<void> signUp({
    required String fullName,
    required String email,
    required String password,
  }) async {
    await _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {'full_name': fullName.trim()},
    );
  }

  @override
  Future<void> signOut() => _client.auth.signOut();
}
