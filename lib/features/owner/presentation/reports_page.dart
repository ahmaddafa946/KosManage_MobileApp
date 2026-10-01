import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/owner_reports_repository.dart';
import '../../../domain/models/owner_management.dart';
import '../../../domain/services/owner_display.dart';
import '../application/owner_module_providers.dart';

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  late final Future<OwnerProperty> _propertyFuture;
  Future<OwnerOperationalReport>? _operationalFuture;
  Future<OwnerFinancialReport>? _financialFuture;

  int _mode = 0;
  int _months = 6;
  String _status = 'all';

  static const _statusOptions = [
    ('all', 'Semua'),
    ('submitted', 'Diajukan'),
    ('in_progress', 'Diproses'),
    ('resolved', 'Selesai'),
    ('closed', 'Ditutup'),
  ];

  @override
  void initState() {
    super.initState();
    _propertyFuture = ref.read(ownerPropertyProvider.future);
    _propertyFuture.then((property) {
      if (!mounted) return;
      setState(() {
        _operationalFuture = ref
            .read(ownerReportsRepositoryProvider)
            .getOperationalReport(property.id);
        _financialFuture = ref
            .read(ownerReportsRepositoryProvider)
            .getFinancialReport(
              property.id,
              months: _months,
            );
      });
    });
  }

  Future<void> _refresh() async {
    final property = await _propertyFuture;
    if (!mounted) return;
    setState(() {
      _operationalFuture = ref
          .read(ownerReportsRepositoryProvider)
          .getOperationalReport(property.id);
      _financialFuture = ref
          .read(ownerReportsRepositoryProvider)
          .getFinancialReport(
            property.id,
            months: _months,
          );
    });
  }

  Future<void> _setMaintenanceStatus(
    OwnerMaintenanceReport report,
    String status,
  ) async {
    try {
      await ref
          .read(ownerReportsRepositoryProvider)
          .updateMaintenanceStatus(report.id, status);
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyError(error))),
      );
    }
  }

  List<(String, String)> _nextStatuses(String status) {
    switch (status) {
      case 'submitted':
        return const [('in_progress', 'Mulai proses')];
      case 'in_progress':
        return const [('resolved', 'Tandai selesai')];
      case 'resolved':
        return const [('closed', 'Tutup laporan')];
      default:
        return const [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<OwnerProperty>(
      future: _propertyFuture,
      builder: (context, propertySnapshot) {
        if (propertySnapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (propertySnapshot.hasError || propertySnapshot.data == null) {
          return _ErrorState(
            message: _friendlyError(propertySnapshot.error),
            onRetry: _refresh,
          );
        }

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
            children: [
              Text(
                'Pantau kondisi operasional dan ringkasan keuangan kos.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 14),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(
                    value: 0,
                    icon: Icon(Icons.build_outlined),
                    label: Text('Operasional'),
                  ),
                  ButtonSegment(
                    value: 1,
                    icon: Icon(Icons.account_balance_wallet_outlined),
                    label: Text('Keuangan'),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (values) {
                  setState(() => _mode = values.first);
                },
              ),
              const SizedBox(height: 16),
              if (_mode == 0)
                _OperationalView(
                  future: _operationalFuture,
                  status: _status,
                  statusOptions: _statusOptions,
                  nextStatuses: _nextStatuses,
                  onStatusChanged: (value) =>
                      setState(() => _status = value),
                  onAdvance: _setMaintenanceStatus,
                )
              else
                _FinancialView(
                  future: _financialFuture,
                  months: _months,
                  onMonthsChanged: (value) {
                    if (value == null) return;
                    final property = propertySnapshot.data!;
                    setState(() {
                      _months = value;
                      _financialFuture = ref
                          .read(ownerReportsRepositoryProvider)
                          .getFinancialReport(
                            property.id,
                            months: value,
                          );
                    });
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

class _OperationalView extends StatelessWidget {
  const _OperationalView({
    required this.future,
    required this.status,
    required this.statusOptions,
    required this.nextStatuses,
    required this.onStatusChanged,
    required this.onAdvance,
  });

  final Future<OwnerOperationalReport>? future;
  final String status;
  final List<(String, String)> statusOptions;
  final List<(String, String)> Function(String) nextStatuses;
  final ValueChanged<String> onStatusChanged;
  final Future<void> Function(OwnerMaintenanceReport, String) onAdvance;

  @override
  Widget build(BuildContext context) {
    final future = this.future;
    if (future == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return FutureBuilder<OwnerOperationalReport>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || snapshot.data == null) {
          return _ErrorState(
            message: _friendlyError(snapshot.error),
            onRetry: () {},
          );
        }

        final report = snapshot.data!;
        final visible = status == 'all'
            ? report.activeMaintenance
            : report.activeMaintenance
                .where((item) => item.status == status)
                .toList(growable: false);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _OperationalKpis(report: report),
            const SizedBox(height: 16),
            Text(
              'Laporan Maintenance',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: statusOptions
                    .map(
                      (option) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(option.$2),
                          selected: status == option.$1,
                          onSelected: (_) => onStatusChanged(option.$1),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 12),
            if (visible.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(26),
                  child: Center(
                    child: Text(
                      report.activeMaintenance.isEmpty
                          ? 'Belum ada laporan maintenance aktif.'
                          : 'Tidak ada laporan pada filter ini.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              )
            else
              ...visible.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _MaintenanceCard(
                    report: item,
                    actions: nextStatuses(item.status),
                    onAdvance: (next) => onAdvance(item, next),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _OperationalKpis extends StatelessWidget {
  const _OperationalKpis({required this.report});

  final OwnerOperationalReport report;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.35,
      children: [
        _Kpi(
          icon: Icons.percent,
          title: 'Okupansi',
          value: report.occupancyRate.toString() + '%',
          detail: report.occupiedRooms.toString() +
              ' dari ' +
              report.totalRooms.toString() +
              ' kamar',
        ),
        _Kpi(
          icon: Icons.meeting_room_outlined,
          title: 'Kamar kosong',
          value: report.availableRooms.toString(),
        ),
        _Kpi(
          icon: Icons.home_repair_service_outlined,
          title: 'Maintenance',
          value: report.maintenanceRooms.toString(),
        ),
        _Kpi(
          icon: Icons.pending_actions_outlined,
          title: 'Laporan aktif',
          value: report.activeMaintenance.length.toString(),
        ),
      ],
    );
  }
}

class _FinancialView extends StatelessWidget {
  const _FinancialView({
    required this.future,
    required this.months,
    required this.onMonthsChanged,
  });

  final Future<OwnerFinancialReport>? future;
  final int months;
  final ValueChanged<int?> onMonthsChanged;

  @override
  Widget build(BuildContext context) {
    if (future == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return FutureBuilder<OwnerFinancialReport>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || snapshot.data == null) {
          return _ErrorState(
            message: _friendlyError(snapshot.error),
            onRetry: () {},
          );
        }

        final report = snapshot.data!;
        final summary = report.summary;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<int>(
              initialValue: months,
              decoration: const InputDecoration(
                labelText: 'Periode laporan',
              ),
              items: const [
                DropdownMenuItem(value: 1, child: Text('1 bulan')),
                DropdownMenuItem(value: 3, child: Text('3 bulan')),
                DropdownMenuItem(value: 6, child: Text('6 bulan')),
                DropdownMenuItem(value: 12, child: Text('12 bulan')),
              ],
              onChanged: onMonthsChanged,
            ),
            const SizedBox(height: 14),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.2,
              children: [
                _MoneyKpi(
                  title: 'Total Tagihan',
                  value: formatRupiah(summary.totalBill),
                  icon: Icons.receipt_long_outlined,
                ),
                _MoneyKpi(
                  title: 'Total Dibayar',
                  value: formatRupiah(summary.totalPaid),
                  icon: Icons.payments_outlined,
                ),
                _MoneyKpi(
                  title: 'Tunggakan',
                  value: formatRupiah(summary.outstanding),
                  icon: Icons.warning_amber_rounded,
                ),
                _MoneyKpi(
                  title: 'Rasio Dibayar',
                  value: (summary.paidRatio * 100).toStringAsFixed(0) + '%',
                  icon: Icons.donut_small_outlined,
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              'Ringkasan per bulan',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            if (report.monthly.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(26),
                  child: Center(
                    child: Text(
                      'Belum ada data pembayaran pada periode ini.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              )
            else
              Card(
                child: Column(
                  children: report.monthly
                      .map(
                        (row) => ListTile(
                          title: Text(row.period),
                          subtitle: Text(
                            'Tagihan ' +
                                formatRupiah(row.amountDue) +
                                ' · Tunggakan ' +
                                formatRupiah(row.outstanding),
                          ),
                          trailing: Text(
                            formatRupiah(row.amountPaid),
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({
    required this.icon,
    required this.title,
    required this.value,
    this.detail,
  });

  final IconData icon;
  final String title;
  final String value;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon),
            const Spacer(),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (detail != null)
              Text(
                detail!,
                style: Theme.of(context).textTheme.labelSmall,
              ),
          ],
        ),
      ),
    );
  }
}

class _MoneyKpi extends StatelessWidget {
  const _MoneyKpi({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon),
            const Spacer(),
            Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _MaintenanceCard extends StatelessWidget {
  const _MaintenanceCard({
    required this.report,
    required this.actions,
    required this.onAdvance,
  });

  final OwnerMaintenanceReport report;
  final List<(String, String)> actions;
  final Future<void> Function(String) onAdvance;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    report.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                _Badge(label: maintenanceStatusLabel(report.status)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              (report.roomNumber == null
                      ? 'Kamar -'
                      : 'Kamar ' + report.roomNumber!) +
                  ' · ' +
                  (report.tenantName ?? 'Penghuni') +
                  ' · ' +
                  maintenanceCategoryLabel(report.category),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 6),
            Text(report.description),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.flag_outlined,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 5),
                Text(
                  'Prioritas ' +
                      maintenancePriorityLabel(report.priority),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const Spacer(),
                if (actions.isNotEmpty)
                  FilledButton.tonal(
                    onPressed: () => onAdvance(actions.first.$1),
                    child: Text(actions.first.$2),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
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
            const Icon(Icons.cloud_off_outlined, size: 48),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 14),
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

String _friendlyError(Object? error) {
  final text = error?.toString().toLowerCase() ?? '';
  if (text.contains('permission') || text.contains('denied')) {
    return 'Akses laporan ditolak.';
  }
  if (text.contains('not found')) {
    return 'Data laporan tidak ditemukan.';
  }
  return 'Laporan tidak dapat dimuat. Silakan coba lagi.';
}
