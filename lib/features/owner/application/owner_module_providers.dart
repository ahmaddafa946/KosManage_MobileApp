import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/repositories/owner_payments_repository.dart';
import '../../../data/repositories/owner_property_repository.dart';
import '../../../data/repositories/owner_reports_repository.dart';
import '../../../data/repositories/owner_rooms_repository.dart';
import '../../../data/repositories/owner_tenants_repository.dart';
import '../../../domain/models/owner_management.dart';

final ownerPropertyRepositoryProvider = Provider<OwnerPropertyRepository>((
  ref,
) {
  return SupabaseOwnerPropertyRepository(Supabase.instance.client);
});

final ownerRoomsRepositoryProvider = Provider<OwnerRoomsRepository>((ref) {
  return SupabaseOwnerRoomsRepository(Supabase.instance.client);
});

final ownerTenantsRepositoryProvider = Provider<OwnerTenantsRepository>((ref) {
  return SupabaseOwnerTenantsRepository(Supabase.instance.client);
});

final ownerPaymentsRepositoryProvider = Provider<OwnerPaymentsRepository>((
  ref,
) {
  return SupabaseOwnerPaymentsRepository(Supabase.instance.client);
});

final ownerReportsRepositoryProvider = Provider<OwnerReportsRepository>((ref) {
  return SupabaseOwnerReportsRepository(Supabase.instance.client);
});

final ownerPropertyProvider = FutureProvider<OwnerProperty>((ref) async {
  final session = Supabase.instance.client.auth.currentSession;
  if (session == null) {
    throw StateError('Sesi login tidak ditemukan.');
  }
  return ref
      .read(ownerPropertyRepositoryProvider)
      .getPrimaryProperty(session.user.id);
});
