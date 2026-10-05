import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../domain/models/owner_dashboard_data.dart';
import '../application/owner_dashboard_provider.dart';

class OwnerDashboardPage extends ConsumerWidget {
  const OwnerDashboardPage({super.key, this.onNavigateTab});

  final ValueChanged<int>? onNavigateTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(ownerDashboardProvider);
    return dashboard.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, _) => _DashboardError(
        message: error is StateError
            ? error.message
            : 'Dashboard tidak dapat dimuat. Periksa koneksi internet.',
        onRetry: () => ref.invalidate(ownerDashboardProvider),
      ),
      data: (data) => RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(ownerDashboardProvider);
          await ref.read(ownerDashboardProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            // Property Header Card
            _HeaderCard(propertyName: data.propertyName),
            const SizedBox(height: 16),

            // Quick Actions
            _QuickActionsRow(onNavigate: onNavigateTab),
            const SizedBox(height: 20),

            // Section Header: Statistik
            Text(
              'Ringkasan Operasional',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 8),
            _SummaryGrid(data: data),
            const SizedBox(height: 24),

            // Section: Pembayaran Terbaru
            _PaymentSection(
              title: 'Pembayaran Terbaru',
              icon: Icons.payments_outlined,
              items: data.recentPayments,
              emptyText: 'Belum ada pembayaran terbaru yang tercatat.',
              onViewAll: onNavigateTab != null ? () => onNavigateTab!(3) : null,
            ),
            const SizedBox(height: 16),

            // Section: Mendekati Jatuh Tempo
            _PaymentSection(
              title: 'Mendekati Jatuh Tempo (7 Hari)',
              icon: Icons.schedule_rounded,
              iconColor: Colors.amber.shade700,
              items: data.upcomingPayments,
              emptyText: 'Tidak ada pembayaran yang jatuh tempo dalam 7 hari.',
              onViewAll: onNavigateTab != null ? () => onNavigateTab!(3) : null,
            ),
            const SizedBox(height: 16),

            // Section: Tunggakan
            _PaymentSection(
              title: 'Tunggakan Aktif',
              icon: Icons.warning_amber_rounded,
              iconColor: Theme.of(context).colorScheme.error,
              items: data.overduePayments,
              emptyText: 'Hebat! Tidak ada tunggakan pembayaran yang aktif.',
              onViewAll: onNavigateTab != null ? () => onNavigateTab!(3) : null,
            ),
            const SizedBox(height: 16),

            // Section: Maintenance
            _MaintenanceSection(
              items: data.activeMaintenance,
              onViewAll: onNavigateTab != null ? () => onNavigateTab!(4) : null,
            ),
            const SizedBox(height: 16),

            // Section: Expiry
            _ExpirySection(
              items: data.expiringTenants,
              onViewAll: onNavigateTab != null ? () => onNavigateTab!(2) : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.propertyName});
  final String propertyName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primaryContainer.withValues(alpha: 0.7),
            colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.apartment_rounded, size: 14, color: Colors.white),
                    SizedBox(width: 4),
                    Text(
                      'PROPERTI',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF10B981),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Terhubung',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            propertyName,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Kelola hunian secara terpusat dan efisien.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionsRow extends StatelessWidget {
  const _QuickActionsRow({this.onNavigate});
  final ValueChanged<int>? onNavigate;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _QuickActionItem(
          label: 'Kamar',
          icon: Icons.meeting_room_outlined,
          onTap: () => onNavigate?.call(1),
        ),
        const SizedBox(width: 10),
        _QuickActionItem(
          label: 'Penghuni',
          icon: Icons.people_outline,
          onTap: () => onNavigate?.call(2),
        ),
        const SizedBox(width: 10),
        _QuickActionItem(
          label: 'Bayar',
          icon: Icons.payments_outlined,
          onTap: () => onNavigate?.call(3),
        ),
        const SizedBox(width: 10),
        _QuickActionItem(
          label: 'Laporan',
          icon: Icons.insights_outlined,
          onTap: () => onNavigate?.call(4),
        ),
      ],
    );
  }
}

class _QuickActionItem extends StatelessWidget {
  const _QuickActionItem({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Expanded(
      child: Material(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 22, color: colorScheme.primary),
                const SizedBox(height: 6),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.data});
  final OwnerDashboardData data;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: itemWidth,
              child: _KpiCard(
                label: 'Total Kamar',
                value: data.totalRooms.toString(),
                icon: Icons.meeting_room_outlined,
                detail: '${data.occupiedRooms} terisi · ${data.availableRooms} kosong',
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: _KpiCard(
                label: 'Penghuni Aktif',
                value: data.activeTenants.toString(),
                icon: Icons.people_outline,
                detail: 'Hunian berjalan',
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: _KpiCard(
                label: 'Pemasukan Bulan Ini',
                value: _currency(data.paidThisMonth),
                icon: Icons.account_balance_wallet_outlined,
                iconColor: const Color(0xFF10B981),
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: _KpiCard(
                label: 'Total Tunggakan',
                value: _currency(data.totalOutstanding),
                icon: Icons.receipt_long_outlined,
                iconColor: data.totalOutstanding > 0
                    ? Theme.of(context).colorScheme.error
                    : null,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    this.detail,
    this.iconColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final String? detail;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final activeIconColor = iconColor ?? scheme.primary;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: activeIconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: activeIconColor, size: 20),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
            ),
            if (detail != null) ...[
              const SizedBox(height: 4),
              Text(
                detail!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PaymentSection extends StatelessWidget {
  const _PaymentSection({
    required this.title,
    required this.icon,
    required this.items,
    required this.emptyText,
    this.iconColor,
    this.onViewAll,
  });

  final String title;
  final IconData icon;
  final List<PaymentPreview> items;
  final String emptyText;
  final Color? iconColor;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: title,
      icon: icon,
      iconColor: iconColor,
      onViewAll: onViewAll,
      child: items.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                emptyText,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            )
          : Column(
              children: items.map((item) {
                final isPaid = item.status == 'paid';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: isPaid
                            ? const Color(0xFF10B981).withValues(alpha: 0.15)
                            : Theme.of(context)
                                .colorScheme
                                .errorContainer
                                .withValues(alpha: 0.4),
                        child: Text(
                          item.roomNumber == '-'
                              ? '?'
                              : item.roomNumber.substring(0, 1),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: isPaid
                                ? const Color(0xFF10B981)
                                : Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.tenantName == '-'
                                  ? 'Penghuni'
                                  : item.tenantName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Kamar ${item.roomNumber} · ${item.billingPeriod}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _currency(
                              item.amountPaid > 0
                                  ? item.amountPaid
                                  : item.amountDue,
                            ),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          _StatusChip(status: item.status),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }
}

class _MaintenanceSection extends StatelessWidget {
  const _MaintenanceSection({required this.items, this.onViewAll});
  final List<MaintenancePreview> items;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Maintenance Aktif',
      icon: Icons.build_outlined,
      onViewAll: onViewAll,
      child: items.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Tidak ada laporan perbaikan aktif.',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            )
          : Column(
              children: items.map((item) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .secondaryContainer
                              .withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.build_circle_outlined, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Kamar ${item.roomNumber} · ${_label(item.priority)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _StatusChip(status: item.status),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }
}

class _ExpirySection extends StatelessWidget {
  const _ExpirySection({required this.items, this.onViewAll});
  final List<ExpiringTenantPreview> items;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Sewa Berakhir Segera (30 Hari)',
      icon: Icons.event_busy_outlined,
      onViewAll: onViewAll,
      child: items.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Tidak ada sewa yang berakhir dalam 30 hari.',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            )
          : Column(
              children: items.map((item) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        child: const Icon(Icons.person_outline, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Kamar ${item.roomNumber}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        _date(item.endDate),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
    this.iconColor,
    this.onViewAll,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final Color? iconColor;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: iconColor ?? colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
                if (onViewAll != null)
                  InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: onViewAll,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      child: Text(
                        'Semua',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const Divider(height: 18),
            child,
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String label;

    switch (status.toLowerCase()) {
      case 'paid':
        bg = const Color(0xFF10B981).withValues(alpha: 0.15);
        fg = const Color(0xFF047857);
        label = 'Lunas';
        break;
      case 'overdue':
        bg = Colors.red.shade100;
        fg = Colors.red.shade800;
        label = 'Terlambat';
        break;
      case 'unpaid':
        bg = Colors.amber.shade100;
        fg = Colors.amber.shade900;
        label = 'Belum';
        break;
      case 'partial':
        bg = Colors.blue.shade100;
        fg = Colors.blue.shade800;
        label = 'Sebagian';
        break;
      case 'in_progress':
        bg = Colors.blue.shade100;
        fg = Colors.blue.shade800;
        label = 'Proses';
        break;
      case 'resolved':
        bg = const Color(0xFF10B981).withValues(alpha: 0.15);
        fg = const Color(0xFF047857);
        label = 'Selesai';
        break;
      default:
        bg = Theme.of(context).colorScheme.surfaceContainerHighest;
        fg = Theme.of(context).colorScheme.onSurfaceVariant;
        label = _label(status);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}

class _DashboardError extends StatelessWidget {
  const _DashboardError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 52),
            const SizedBox(height: 14),
            const Text(
              'Dashboard belum dapat dimuat.',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba lagi'),
            ),
          ],
        ),
      ),
    );
  }
}

String _currency(num amount) => NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(amount);

String _date(DateTime? value) =>
    value == null ? '-' : DateFormat('dd MMM yyyy', 'id_ID').format(value);

String _label(String value) => value
    .replaceAll('_', ' ')
    .split(' ')
    .map(
      (word) =>
          word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}',
    )
    .join(' ');
