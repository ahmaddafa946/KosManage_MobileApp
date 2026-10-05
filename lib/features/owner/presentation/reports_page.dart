import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/owner_reports_repository.dart';
import '../../../domain/models/owner_management.dart';
import '../../../domain/services/owner_display.dart';
import '../../shared/presentation/app_ui.dart';
import '../application/owner_module_providers.dart';

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  late final Future<OwnerProperty> _propertyFuture;
  Future<OwnerOperationalReport>? _operationalFuture;
  Future<List<OwnerMaintenanceReport>>? _maintenanceFuture;
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
        final repository = ref.read(ownerReportsRepositoryProvider);
        _operationalFuture = repository.getOperationalReport(property.id);
        _maintenanceFuture = repository.getMaintenanceReports(property.id);
        _financialFuture = repository.getFinancialReport(property.id, months: _months);
      });
    });
  }

  Future<void> _refresh() async {
    final property = await _propertyFuture;
    if (!mounted) return;
    setState(() {
      final repository = ref.read(ownerReportsRepositoryProvider);
      _operationalFuture = repository.getOperationalReport(property.id);
      _maintenanceFuture = repository.getMaintenanceReports(property.id);
      _financialFuture = repository.getFinancialReport(property.id, months: _months);
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
        SnackBar(
          content: Text(_friendlyError(error)),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
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
          return AppErrorState(
            message: _friendlyError(propertySnapshot.error),
            onRetry: _refresh,
          );
        }
        final property = propertySnapshot.data!;

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
            children: [
              Text(
                property.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                'Kondisi operasional dan ringkasan keuangan kos.',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 14),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(
                    value: 0,
                    icon: Icon(Icons.build_outlined, size: 18),
                    label: Text('Operasional'),
                  ),
                  ButtonSegment(
                    value: 1,
                    icon: Icon(Icons.account_balance_wallet_outlined, size: 18),
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
                  maintenanceFuture: _maintenanceFuture,
                  status: _status,
                  statusOptions: _statusOptions,
                  nextStatuses: _nextStatuses,
                  onStatusChanged: (value) => setState(() => _status = value),
                  onAdvance: _setMaintenanceStatus,
                  onRetry: _refresh,
                )
              else
                _FinancialView(
                  future: _financialFuture,
                  months: _months,
                  onRetry: _refresh,
                  onMonthsChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _months = value;
                      _financialFuture = ref
                          .read(ownerReportsRepositoryProvider)
                          .getFinancialReport(property.id, months: value);
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
    required this.maintenanceFuture,
    required this.status,
    required this.statusOptions,
    required this.nextStatuses,
    required this.onStatusChanged,
    required this.onAdvance,
    required this.onRetry,
  });

  final Future<OwnerOperationalReport>? future;
  final Future<List<OwnerMaintenanceReport>>? maintenanceFuture;
  final String status;
  final List<(String, String)> statusOptions;
  final List<(String, String)> Function(String) nextStatuses;
  final ValueChanged<String> onStatusChanged;
  final Future<void> Function(OwnerMaintenanceReport, String) onAdvance;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final future = this.future;
    if (future == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    return FutureBuilder<OwnerOperationalReport>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          );
        }
        if (snapshot.hasError || snapshot.data == null) {
          return AppErrorState(
            message: _friendlyError(snapshot.error),
            onRetry: onRetry,
          );
        }

        final report = snapshot.data!;
        final maintenanceFuture = this.maintenanceFuture;
        if (maintenanceFuture == null) {
          return AppErrorState(
            message: 'Laporan maintenance belum siap.',
            onRetry: onRetry,
          );
        }

        return FutureBuilder<List<OwnerMaintenanceReport>>(
          future: maintenanceFuture,
          builder: (context, maintenanceSnapshot) {
            if (maintenanceSnapshot.connectionState != ConnectionState.done) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _OperationalKpis(report: report),
                  const SizedBox(height: 16),
                  const Center(child: CircularProgressIndicator()),
                ],
              );
            }
            if (maintenanceSnapshot.hasError) {
              return AppErrorState(
                message: _friendlyError(maintenanceSnapshot.error),
                onRetry: onRetry,
              );
            }

            final maintenance =
                maintenanceSnapshot.data ?? const <OwnerMaintenanceReport>[];
            final visible = status == 'all'
                ? maintenance
                : maintenance
                    .where((item) => item.status == status)
                    .toList(growable: false);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _OperationalKpis(report: report),
                const SizedBox(height: 20),
                Text(
                  'Laporan Maintenance (${visible.length})',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: statusOptions
                        .map(
                          (option) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(option.$2),
                              selected: status == option.$1,
                              onSelected: (_) =>
                                  onStatusChanged(option.$1),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 12),
                if (visible.isEmpty)
                  AppEmptyState(
                    icon: Icons.handyman_outlined,
                    title: 'Tidak ada laporan',
                    message: maintenance.isEmpty
                        ? 'Belum ada laporan maintenance dari penghuni.'
                        : 'Tidak ada laporan pada filter ini.',
                  )
                else
                  ...visible.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
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
      },
    );
  }
}

class _OperationalKpis extends StatelessWidget {
  const _OperationalKpis({required this.report});

  final OwnerOperationalReport report;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: w,
              child: _KpiCard(
                icon: Icons.percent,
                title: 'Okupansi',
                value: '${report.occupancyRate}%',
                detail:
                    '${report.occupiedRooms} dari ${report.totalRooms} kamar',
              ),
            ),
            SizedBox(
              width: w,
              child: _KpiCard(
                icon: Icons.meeting_room_outlined,
                title: 'Kamar kosong',
                value: '${report.availableRooms}',
                detail: 'Siap dihuni',
              ),
            ),
            SizedBox(
              width: w,
              child: _KpiCard(
                icon: Icons.home_repair_service_outlined,
                title: 'Maintenance',
                value: '${report.maintenanceRooms}',
                detail: 'Kamar dalam perbaikan',
              ),
            ),
            SizedBox(
              width: w,
              child: _KpiCard(
                icon: Icons.pending_actions_outlined,
                title: 'Laporan aktif',
                value: '${report.activeMaintenance.length}',
                detail: 'Perlu tindakan',
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
    final scheme = Theme.of(context).colorScheme;
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
                color: scheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: scheme.primary, size: 20),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 17),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant),
            ),
            if (detail != null) ...[
              const SizedBox(height: 2),
              Text(
                detail!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 11, color: scheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FinancialView extends StatelessWidget {
  const _FinancialView({
    required this.future,
    required this.months,
    required this.onMonthsChanged,
    required this.onRetry,
  });

  final Future<OwnerFinancialReport>? future;
  final int months;
  final ValueChanged<int?> onMonthsChanged;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (future == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    return FutureBuilder<OwnerFinancialReport>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          );
        }
        if (snapshot.hasError || snapshot.data == null) {
          return AppErrorState(
            message: _friendlyError(snapshot.error),
            onRetry: onRetry,
          );
        }

        final report = snapshot.data!;
        final summary = report.summary;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<int>(
              initialValue: months,
              isExpanded: true,
              decoration:
                  const InputDecoration(labelText: 'Periode laporan'),
              items: const [
                DropdownMenuItem(
                    value: 1,
                    child: Text('1 bulan',
                        maxLines: 1, overflow: TextOverflow.ellipsis)),
                DropdownMenuItem(
                    value: 3,
                    child: Text('3 bulan',
                        maxLines: 1, overflow: TextOverflow.ellipsis)),
                DropdownMenuItem(
                    value: 6,
                    child: Text('6 bulan',
                        maxLines: 1, overflow: TextOverflow.ellipsis)),
                DropdownMenuItem(
                    value: 12,
                    child: Text('12 bulan',
                        maxLines: 1, overflow: TextOverflow.ellipsis)),
              ],
              onChanged: onMonthsChanged,
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final w = (constraints.maxWidth - 12) / 2;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: w,
                      child: _KpiCard(
                        icon: Icons.receipt_long_outlined,
                        title: 'Total Tagihan',
                        value: formatRupiah(summary.totalBill),
                      ),
                    ),
                    SizedBox(
                      width: w,
                      child: _KpiCard(
                        icon: Icons.payments_outlined,
                        title: 'Total Dibayar',
                        value: formatRupiah(summary.totalPaid),
                      ),
                    ),
                    SizedBox(
                      width: w,
                      child: _KpiCard(
                        icon: Icons.warning_amber_rounded,
                        title: 'Tunggakan',
                        value: formatRupiah(summary.outstanding),
                      ),
                    ),
                    SizedBox(
                      width: w,
                      child: _KpiCard(
                        icon: Icons.donut_small_outlined,
                        title: 'Rasio Dibayar',
                        value:
                            '${(summary.paidRatio * 100).toStringAsFixed(0)}%',
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            const Text('Rincian per bulan',
                style:
                    TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 8),
            if (report.monthly.isEmpty)
              const AppEmptyState(
                icon: Icons.bar_chart_outlined,
                title: 'Belum ada data',
                message: 'Belum ada pembayaran pada periode ini.',
              )
            else
              Card(
                child: Column(
                  children: report.monthly
                      .map(
                        (row) => ListTile(
                          dense: true,
                          title: Text(row.period,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          subtitle: Text(
                            'Tagihan ${formatRupiah(row.amountDue)} · Tunggakan ${formatRupiah(row.outstanding)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: ConstrainedBox(
                            constraints:
                                const BoxConstraints(maxWidth: 120),
                            child: Text(
                              formatRupiah(row.amountPaid),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.end,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13),
                            ),
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
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    report.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 8),
                AppStatusChip(
                  label: maintenanceStatusLabel(report.status),
                  tone: maintenanceTone(report.status),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${report.roomNumber == null ? 'Kamar -' : 'Kamar ${report.roomNumber}'} · ${report.tenantName ?? 'Penghuni'} · ${maintenanceCategoryLabel(report.category)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 6),
            Text(
              report.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.flag_outlined,
                    size: 16, color: scheme.primary),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    'Prioritas ${maintenancePriorityLabel(report.priority)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12, color: scheme.onSurfaceVariant),
                  ),
                ),
                if (actions.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                    onPressed: () => onAdvance(actions.first.$1),
                    child: Text(actions.first.$2),
                  ),
                ],
              ],
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
