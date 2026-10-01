import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/repositories/owner_dashboard_repository.dart';
import '../../auth/application/auth_controller.dart';
import '../../../domain/models/owner_dashboard_data.dart';

final ownerDashboardRepositoryProvider = Provider<OwnerDashboardRepository>((
  ref,
) {
  return SupabaseOwnerDashboardRepository(Supabase.instance.client);
});

final ownerDashboardProvider = FutureProvider<OwnerDashboardData>((ref) async {
  final session = ref.read(authRepositoryProvider).currentSession;
  if (session == null) {
    throw StateError('Tidak ada sesi login.');
  }

  return ref.read(ownerDashboardRepositoryProvider).load(session.user.id);
});
