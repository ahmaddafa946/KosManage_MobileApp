import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/models/user_profile.dart';
import 'owner_dashboard_page.dart';
import 'payments_page.dart';
import 'reports_page.dart';
import 'rooms_page.dart';
import 'tenants_page.dart';

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

  Widget _buildPage() {
    switch (_index) {
      case 1:
        return const RoomsPage();
      case 2:
        return const TenantsPage();
      case 3:
        return const PaymentsPage();
      case 4:
        return const ReportsPage();
      default:
        return const OwnerDashboardPage();
    }
  }

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
      body: _buildPage(),

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
