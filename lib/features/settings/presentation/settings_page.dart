import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../domain/models/app_role.dart';
import '../../auth/application/auth_controller.dart';
import '../../home/presentation/home_gate_page.dart';
import '../../tenant/presentation/tenant_shell_page.dart';
import 'theme_controller.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  Future<void> _showLogoutDialog(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Keluar dari Akun?'),
        content: const Text(
          'Sesi login Anda akan diakhiri. Anda perlu memasukkan email dan kata sandi kembali untuk masuk.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await ref.read(authControllerProvider.notifier).signOut();
        ref
          ..invalidate(currentProfileProvider)
          ..invalidate(currentTenantProvider);
        if (context.mounted) {
          context.go('/login');
        }
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Logout gagal. Periksa koneksi lalu coba lagi.',
              ),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeModeProvider);
    final currentMode = themeState.value ?? ThemeMode.system;
    final profileAsync = ref.watch(currentProfileProvider);
    final userEmail = Supabase.instance.client.auth.currentUser?.email;
    final colorScheme = Theme.of(context).colorScheme;

    Future<void> setTheme(ThemeMode? mode) async {
      if (mode != null) {
        await ref.read(themeModeProvider.notifier).setThemeMode(mode);
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil & Pengaturan'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // User Profile Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: profileAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (_, _) => Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: colorScheme.primaryContainer,
                      child: Icon(Icons.person_rounded, size: 32, color: colorScheme.primary),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userEmail ?? 'Pengguna',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Sesi aktif',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                data: (profile) {
                  final initial = profile.name.isNotEmpty
                      ? profile.name.substring(0, 1).toUpperCase()
                      : 'U';
                  final roleLabel = profile.role == AppRole.owner
                      ? 'Pemilik Kos'
                      : 'Penghuni Kos';

                  return Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: colorScheme.primaryContainer,
                        child: Text(
                          initial,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile.name,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (userEmail != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                userEmail,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: colorScheme.secondaryContainer,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                roleLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSecondaryContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Theme Settings Section
          Text(
            'Tampilan Aplikasi',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: RadioGroup<ThemeMode>(
              groupValue: currentMode,
              onChanged: setTheme,
              child: const Column(
                children: [
                  RadioListTile<ThemeMode>(
                    value: ThemeMode.system,
                    title: Text('Ikuti sistem'),
                    subtitle: Text('Mengikuti mode terang/gelap perangkat.'),
                  ),
                  Divider(height: 1, indent: 16, endIndent: 16),
                  RadioListTile<ThemeMode>(
                    value: ThemeMode.light,
                    title: Text('Mode terang'),
                  ),
                  Divider(height: 1, indent: 16, endIndent: 16),
                  RadioListTile<ThemeMode>(
                    value: ThemeMode.dark,
                    title: Text('Mode gelap'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Security & System info
          Text(
            'Informasi & Keamanan',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.shield_outlined, color: colorScheme.primary, size: 24),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Aplikasi mobile terhubung aman dengan Supabase. Kunci rahasia backend terlindungi di server.',
                      style: TextStyle(fontSize: 13, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),

          // Logout Button
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.errorContainer,
              foregroundColor: colorScheme.onErrorContainer,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => _showLogoutDialog(context, ref),
            icon: const Icon(Icons.logout_rounded),
            label: const Text(
              'Keluar dari Akun',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
