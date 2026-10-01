import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/models/user_profile.dart';
import '../../auth/application/auth_controller.dart';
import '../../home/presentation/home_gate_page.dart';
import '../../shared/presentation/feature_placeholder_page.dart';

class TenantShellPage extends StatefulWidget {
  const TenantShellPage({super.key, required this.profile});

  final UserProfile profile;

  @override
  State<TenantShellPage> createState() => _TenantShellPageState();
}

class _TenantShellPageState extends State<TenantShellPage> {
  int _index = 0;

  static const _items = [
    (
      label: 'Dashboard',
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard_rounded,
      title: 'Dashboard',
      description: 'Ringkasan kamar, sewa, pembayaran, dan maintenance Anda.',
    ),
    (
      label: 'Kamar Saya',
      icon: Icons.meeting_room_outlined,
      selectedIcon: Icons.meeting_room_rounded,
      title: 'Kamar Saya',
      description: 'Detail kamar dan informasi sewa.',
    ),
    (
      label: 'Pembayaran',
      icon: Icons.payments_outlined,
      selectedIcon: Icons.payments_rounded,
      title: 'Pembayaran',
      description: 'Tagihan dan histori pembayaran.',
    ),
    (
      label: 'Laporan',
      icon: Icons.build_outlined,
      selectedIcon: Icons.build_rounded,
      title: 'Laporan',
      description: 'Buat dan pantau laporan maintenance.',
    ),
    (
      label: 'Riwayat',
      icon: Icons.history_outlined,
      selectedIcon: Icons.history_rounded,
      title: 'Riwayat',
      description: 'Riwayat pembayaran dan aktivitas.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final item = _items[_index];

    return Scaffold(
      appBar: AppBar(
        title: Text(item.title),
        actions: [
          IconButton(
            tooltip: 'Pengaturan',
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: _index == 0
          ? _TenantWelcome(profile: widget.profile)
          : FeaturePlaceholderPage(
              title: item.title,
              description: item.description,
              icon: item.selectedIcon,
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: _items
            .map(
              (item) => NavigationDestination(
                icon: Icon(item.icon),
                selectedIcon: Icon(item.selectedIcon),
                label: item.label,
              ),
            )
            .toList(),
      ),
    );
  }
}

class _TenantWelcome extends ConsumerWidget {
  const _TenantWelcome({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Text(
          'Halo, ${profile.name}',
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          'Fondasi dashboard tenant siap untuk dihubungkan ke data kamar dan pembayaran.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 20),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Kamar Saya'),
                SizedBox(height: 6),
                Text('Belum terhubung ke data kamar aktif.'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tagihan'),
                SizedBox(height: 6),
                Text('Belum terhubung ke query pembayaran.'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        FilledButton.tonalIcon(
          onPressed: () async {
            await ref.read(authControllerProvider.notifier).signOut();
            ref.invalidate(currentProfileProvider);
            if (context.mounted) context.go('/login');
          },
          icon: const Icon(Icons.logout),
          label: const Text('Keluar'),
        ),
      ],
    );
  }
}
