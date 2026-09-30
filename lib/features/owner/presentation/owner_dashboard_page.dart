import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../domain/models/owner_dashboard_data.dart';
import '../application/owner_dashboard_provider.dart';

class OwnerDashboardPage extends ConsumerWidget {
  const OwnerDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(ownerDashboardProvider);
    return dashboard.when(
      loading: () => const Center(child: CircularProgressIndicator()),
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
            Text(
              data.propertyName,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Ringkasan operasional real-time dari Supabase.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            _SummaryGrid(data: data),
            const SizedBox(height: 20),
            _PaymentSection(
              title: 'Pembayaran Terbaru',
              icon: Icons.payments_outlined,
              items: data.recentPayments,
              emptyText: 'Belum ada pembayaran terbaru.',
            ),
            const SizedBox(height: 14),
            _PaymentSection(
              title: 'Mendekati Jatuh Tempo',
              icon: Icons.schedule_outlined,
              items: data.upcomingPayments,
              emptyText: 'Tidak ada pembayaran yang jatuh tempo dalam 7 hari.',
            ),
            const SizedBox(height: 14),
            _PaymentSection(
              title: 'Tunggakan',
              icon: Icons.warning_amber_rounded,
              items: data.overduePayments,
              emptyText: 'Tidak ada tunggakan aktif.',
            ),
            const SizedBox(height: 14),
            _MaintenanceSection(items: data.activeMaintenance),
            const SizedBox(height: 14),
            _ExpirySection(items: data.expiringTenants),
          ],
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
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.25,
      children: [
        _KpiCard(
          label: 'Total Kamar',
          value: data.totalRooms.toString(),
          icon: Icons.meeting_room_outlined,
          detail:
              '${data.occupiedRooms} terisi · ${data.availableRooms} kosong · ${data.maintenanceRooms} maintenance',
        ),
        _KpiCard(
          label: 'Penghuni Aktif',
          value: data.activeTenants.toString(),
          icon: Icons.people_outline,
        ),
        _KpiCard(
          label: 'Pendapatan Bulan Ini',
          value: _currency(data.paidThisMonth),
          icon: Icons.payments_outlined,
        ),
        _KpiCard(
          label: 'Total Tunggakan',
          value: _currency(data.totalOutstanding),
          icon: Icons.receipt_long_outlined,
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    this.detail,
  });
  final String label;
  final String value;
  final IconData icon;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: scheme.primary),
            const Spacer(),
            Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (detail != null)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  detail!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
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
  });
  final String title;
  final IconData icon;
  final List<PaymentPreview> items;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: title,
      icon: icon,
      child: items.isEmpty
          ? Text(emptyText)
          : Column(
              children: items
                  .map(
                    (item) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        child: Text(
                          item.roomNumber == '-'
                              ? '?'
                              : item.roomNumber.substring(0, 1),
                        ),
                      ),
                      title: Text(
                        item.tenantName == '-'
                            ? 'Penghuni tidak diketahui'
                            : item.tenantName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${item.roomNumber} · ${item.billingPeriod} · ${_label(item.status)}',
                      ),
                      trailing: Text(
                        _currency(
                          item.amountPaid > 0
                              ? item.amountPaid
                              : item.amountDue,
                        ),
                        style:
                            Theme.of(context).textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

class _MaintenanceSection extends StatelessWidget {
  const _MaintenanceSection({required this.items});
  final List<MaintenancePreview> items;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Maintenance Aktif',
      icon: Icons.build_outlined,
      child: items.isEmpty
          ? const Text('Tidak ada maintenance aktif.')
          : Column(
              children: items
                  .map(
                    (item) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.build_circle_outlined),
                      title: Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${item.roomNumber} · ${_label(item.priority)} · ${_label(item.status)}',
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

class _ExpirySection extends StatelessWidget {
  const _ExpirySection({required this.items});
  final List<ExpiringTenantPreview> items;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Sewa Mendekati Berakhir',
      icon: Icons.event_busy_outlined,
      child: items.isEmpty
          ? const Text('Tidak ada sewa yang berakhir dalam 30 hari.')
          : Column(
              children: items
                  .map(
                    (item) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.person_outline),
                      title: Text(item.name),
                      subtitle: Text(
                        '${item.roomNumber} · berakhir ${_date(item.endDate)}',
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });
  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

class _DashboardError extends StatelessWidget {
  const _DashboardError({
    required this.message,
    required this.onRetry,
  });
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
      (word) => word.isEmpty
          ? word
          : '${word[0].toUpperCase()}${word.substring(1)}',
    )
    .join(' ');
