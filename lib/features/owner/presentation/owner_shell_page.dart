import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/models/user_profile.dart';
import '../../auth/application/auth_controller.dart';
import '../../home/presentation/home_gate_page.dart';
import '../../shared/presentation/feature_placeholder_page.dart';

class OwnerShellPage extends StatefulWidget {
  const OwnerShellPage({
    super.key,
    required this.profile,
  });

  final UserProfile profile;

  @override
  State<OwnerShellPage> createState() => _OwnerShellPageState();
}

class _OwnerShellPageState extends State<OwnerShellPage> {
  int _index = 0;

  static const _items = [
    (
      label: 'Dashboard',
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard_rounded,
      title: 'Dashboard',
      description:
          'Ringkasan kamar, penghuni, pemasukan, tagihan, dan maintenance.',
    ),
    (
      label: 'Kamar',
      icon: Icons.meeting_room_outlined,
      selectedIcon: Icons.meeting_room_rounded,
      title: 'Kamar',
      description: 'Daftar kamar akan ditampilkan sebagai list/card mobile.',
    ),
    (
      label: 'Penghuni',
      icon: Icons.people_outline,
      selectedIcon: Icons.people_rounded,
      title: 'Penghuni',
      description: 'Kelola penghuni aktif dan histori penghuni.',
    ),
    (
      label: 'Pembayaran',
      icon: Icons.payments_outlined,
      selectedIcon: Icons.payments_rounded,
      title: 'Pembayaran',
      description: 'Catat dan pantau status pembayaran sewa.',
    ),
    (
      label: 'Laporan',
      icon: Icons.assessment_outlined,
      selectedIcon: Icons.assessment_rounded,
      title: 'Laporan',
      description: 'Laporan operasional dan keuangan.',
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
          ? _DashboardWelcome(profile: widget.profile)
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

class _DashboardWelcome extends ConsumerWidget {
  const _DashboardWelcome({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(currentProfileProvider);
        await ref.read(currentProfileProvider.future);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Text(
            'Halo, ${profile.name}',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Fondasi dashboard owner sudah siap untuk dihubungkan ke query Supabase.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 20),
          Row(
            children: const [
              Expanded(
                child: _MetricCard(
                  label: 'Kamar',
                  value: '—',
                  icon: Icons.meeting_room_outlined,
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: _MetricCard(
                  label: 'Penghuni',
                  value: '—',
                  icon: Icons.people_outline,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: const [
              Expanded(
                child: _MetricCard(
                  label: 'Pendapatan',
                  value: '—',
                  icon: Icons.payments_outlined,
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: _MetricCard(
                  label: 'Tagihan',
                  value: '—',
                  icon: Icons.receipt_long_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Card(
            color: scheme.primaryContainer.withValues(alpha: 0.75),
            child: const Padding(
              padding: EdgeInsets.all(18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.cloud_done_outlined),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Data mobile akan memakai Supabase yang sama dengan aplikasi web/desktop. '
                      'RLS tetap menjadi batas keamanan data.',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: () async {
              await ref.read(authControllerProvider.notifier).signOut();
              if (context.mounted) context.go('/login');
            },
            icon: const Icon(Icons.logout),
            label: const Text('Keluar'),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
