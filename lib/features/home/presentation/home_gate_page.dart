import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../data/repositories/profile_repository.dart';
import '../../../domain/models/app_role.dart';
import '../../../domain/models/user_profile.dart';
import '../../auth/application/auth_controller.dart';
import '../../owner/presentation/owner_shell_page.dart';
import '../../tenant/presentation/tenant_shell_page.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return SupabaseProfileRepository(Supabase.instance.client);
});

final currentProfileProvider = FutureProvider<UserProfile>((ref) async {
  final session = ref.read(authRepositoryProvider).currentSession;
  if (session == null) {
    throw const SessionException();
  }
  return ref.read(profileRepositoryProvider).getCurrentProfile(session.user.id);
});

String profileErrorMessage(Object error) {
  if (error is SessionException) return error.message;
  if (error is NotFoundException) return error.message;
  if (error is AuthorizationException) return error.message;
  if (error is ValidationException) return error.message;
  if (error is NetworkException) return error.message;
  final text = error.toString().toLowerCase();
  if (text.contains('network') ||
      text.contains('socket') ||
      text.contains('timeout') ||
      text.contains('failed host')) {
    return const NetworkException().message;
  }
  return 'Periksa profile dan koneksi Supabase.';
}

class HomeGatePage extends ConsumerWidget {
  const HomeGatePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);

    return profile.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text('KosManage')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.person_off_outlined, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'Profil akun belum dapat dimuat.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  profileErrorMessage(error),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () async {
                    await ref.read(authControllerProvider.notifier).signOut();
                    ref.invalidate(currentProfileProvider);
                    if (context.mounted) context.go('/login');
                  },
                  child: const Text('Kembali ke Login'),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (userProfile) {
        switch (userProfile.role) {
          case AppRole.owner:
            return OwnerShellPage(profile: userProfile);
          case AppRole.tenant:
            return TenantShellPage(profile: userProfile);
        }
      },
    );
  }
}
