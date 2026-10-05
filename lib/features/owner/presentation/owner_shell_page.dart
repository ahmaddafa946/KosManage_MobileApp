import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/models/user_profile.dart';
import 'owner_dashboard_page.dart';
import 'payments_page.dart';
import 'reports_page.dart';
import 'rooms_page.dart';
import 'tenants_page.dart';

class OwnerShellPage extends StatefulWidget {
  const OwnerShellPage({super.key, required this.profile});

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
      title: 'Dashboard Kos',
    ),
    (
      label: 'Kamar',
      icon: Icons.meeting_room_outlined,
      selectedIcon: Icons.meeting_room_rounded,
      title: 'Daftar Kamar',
    ),
    (
      label: 'Penghuni',
      icon: Icons.people_outline,
      selectedIcon: Icons.people_rounded,
      title: 'Kelola Penghuni',
    ),
    (
      label: 'Pembayaran',
      icon: Icons.payments_outlined,
      selectedIcon: Icons.payments_rounded,
      title: 'Catatan Pembayaran',
    ),
    (
      label: 'Laporan',
      icon: Icons.assessment_outlined,
      selectedIcon: Icons.assessment_rounded,
      title: 'Laporan & Keuangan',
    ),
  ];

  void _onNavigate(int index) {
    if (index >= 0 && index < _items.length) {
      setState(() => _index = index);
    }
  }

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
        return OwnerDashboardPage(onNavigateTab: _onNavigate);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = _items[_index];
    final colorScheme = Theme.of(context).colorScheme;
    final initial = widget.profile.name.isNotEmpty
        ? widget.profile.name.substring(0, 1).toUpperCase()
        : 'P';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              item.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            Text(
              'KosManage Mobile',
              style: TextStyle(
                fontSize: 11,
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => context.push('/settings'),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colorScheme.primary.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                ),
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: colorScheme.primaryContainer,
                  child: Text(
                    initial,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ),
            ),
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
