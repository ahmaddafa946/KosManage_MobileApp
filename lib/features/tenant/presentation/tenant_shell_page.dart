import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/repositories/tenant_repository.dart';
import '../../../domain/models/owner_management.dart';
import '../../../domain/models/user_profile.dart';
import '../../../domain/services/owner_display.dart';
import '../../settings/presentation/settings_page.dart';
import '../../shared/presentation/app_ui.dart';

final tenantRepositoryProvider = Provider<TenantRepository>((ref) {
  return SupabaseTenantRepository(Supabase.instance.client);
});

final currentTenantProvider =
    FutureProvider.autoDispose<MyTenant?>((ref) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return null;
  try {
    // ponytail: identity via tenants.profile_id; email only as fallback.
    return await ref.read(tenantRepositoryProvider).getMyTenant(user.id);
  } catch (_) {
    final email = user.email;
    if (email == null || email.isEmpty) return null;
    try {
      return await ref
          .read(tenantRepositoryProvider)
          .getMyTenantByEmail(email);
    } catch (_) {
      return null;
    }
  }
});

class TenantShellPage extends StatefulWidget {
  const TenantShellPage({super.key, required this.profile});

  final UserProfile profile;

  @override
  State<TenantShellPage> createState() => TenantShellPageState();
}

class TenantShellPageState extends State<TenantShellPage> {
  int _index = 0;

  static const _items = [
    (
      label: 'Beranda',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
      title: 'Beranda Saya',
    ),
    (
      label: 'Kamar',
      icon: Icons.meeting_room_outlined,
      selectedIcon: Icons.meeting_room_rounded,
      title: 'Kamar Saya',
    ),
    (
      label: 'Tagihan',
      icon: Icons.payments_outlined,
      selectedIcon: Icons.payments_rounded,
      title: 'Tagihan & Riwayat',
    ),
    (
      label: 'Bantuan',
      icon: Icons.build_outlined,
      selectedIcon: Icons.build_rounded,
      title: 'Bantuan & Laporan',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final item = _items[_index];
    final scheme = Theme.of(context).colorScheme;
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
                color: scheme.onSurfaceVariant,
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
              child: CircleAvatar(
                radius: 16,
                backgroundColor: scheme.primaryContainer,
                child: Text(
                  initial,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: [
          TenantHome(profile: widget.profile),
          _TenantRoomTab(profile: widget.profile),
          _TenantPaymentsTab(profile: widget.profile),
          _TenantMaintenanceTab(profile: widget.profile),
        ],
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

class TenantHome extends ConsumerWidget {
  const TenantHome({super.key, required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _TenantHomeContent(profile: profile);
  }
}

class _TenantHomeContent extends ConsumerWidget {
  const _TenantHomeContent({required this.profile});

  final UserProfile profile;

  String _greeting(DateTime now) {
    final hour = now.hour;
    if (hour < 11) return 'Selamat pagi';
    if (hour < 15) return 'Selamat siang';
    if (hour < 19) return 'Selamat sore';
    return 'Selamat malam';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final initial = profile.name.isNotEmpty
        ? profile.name.substring(0, 1).toUpperCase()
        : 'P';
    final tenantAsync = ref.watch(currentTenantProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(currentTenantProvider);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: scheme.primary,
                  child: Text(
                    initial,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_greeting(DateTime.now())}, ${profile.name}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Row(
                        children: [
                          AppStatusChip(
                            label: 'Penghuni Kos',
                            tone: AppTone.info,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Self-service: kamar, tagihan, bantuan.',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          tenantAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) => const AppEmptyState(
              icon: Icons.person_search_outlined,
              title: 'Data belum terdaftar',
              message:
                  'Akun Anda belum terhubung dengan data kamar aktif. Hubungi pemilik kos.',
            ),
            data: (myTenant) {
              if (myTenant == null) {
                return const AppEmptyState(
                  icon: Icons.person_search_outlined,
                  title: 'Belum Terhubung Kamar',
                  message:
                      'Akun belum diasosiasikan dengan kamar aktif oleh pemilik kos.',
                );
              }
              final t = myTenant.tenant;
              final countdown = rentalCountdown(t.endDate);
              final reportsAsync = ref.watch(
                _tenantReportsProvider(myTenant.tenant.id),
              );
              final billsAsync = ref.watch(
                _tenantRecentPaymentsProvider(myTenant),
              );
              return Column(
                children: [
                  AppSectionCard(
                    title: 'Status Sewa',
                    icon: Icons.home_work_outlined,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                t.roomNumber == null
                                    ? 'Belum ada kamar'
                                    : 'Kamar ${t.roomNumber}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            AppStatusChip(
                              label: countdown.label,
                              tone: _urgencyTone(countdown.urgency),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Sewa: ${formatRupiah(t.rentPrice ?? 0)} / bulan',
                          style: TextStyle(
                            fontSize: 13,
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (t.startDate.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Mulai sewa: ${formatDateId(t.startDate)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _TenantNextBill(billsAsync: billsAsync),
                  const SizedBox(height: 12),
                  _TenantReportSummary(reportsAsync: reportsAsync),
                  const SizedBox(height: 12),
                  _TenantRecentPayments(myTenant: myTenant),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.person_outline, size: 18),
            label: const Text('Profil & Pengaturan'),
          ),
        ],
      ),
    );
  }

  static AppTone _urgencyTone(RentalUrgency urgency) => switch (urgency) {
        RentalUrgency.normal => AppTone.success,
        RentalUrgency.attention => AppTone.info,
        RentalUrgency.soon => AppTone.warning,
        RentalUrgency.verySoon => AppTone.danger,
        RentalUrgency.expired || RentalUrgency.pastDue => AppTone.danger,
      };
}

final _tenantRecentPaymentsProvider =
    FutureProvider.autoDispose.family<List<OwnerPayment>, MyTenant>((
  ref,
  myTenant,
) async {
  return ref
      .watch(tenantRepositoryProvider)
      .getMyPayments(myTenant.propertyId, myTenant.tenant.id);
});

final _tenantReportsProvider =
    FutureProvider.autoDispose.family<List<OwnerMaintenanceReport>, String>((
  ref,
  tenantId,
) async {
  return ref.watch(tenantRepositoryProvider).getMyReports(tenantId);
});

OwnerPayment? nearestUnpaidBill(List<OwnerPayment> bills) {
  final open = bills
      .where((bill) => bill.status != 'paid' && bill.dueDate.isNotEmpty)
      .toList(growable: false)
    ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
  return open.isEmpty ? null : open.first;
}

int openReportCount(List<OwnerMaintenanceReport> reports) {
  return reports
      .where((report) => report.status == 'submitted' || report.status == 'in_progress')
      .length;
}

class _TenantNextBill extends StatelessWidget {
  const _TenantNextBill({required this.billsAsync});

  final AsyncValue<List<OwnerPayment>> billsAsync;

  @override
  Widget build(BuildContext context) {
    return billsAsync.when(
      loading: () => const AppSectionCard(
        title: 'Tagihan Terdekat',
        icon: Icons.payments_outlined,
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(12),
            child: CircularProgressIndicator(),
          ),
        ),
      ),
      error: (_, _) => const AppSectionCard(
        title: 'Tagihan Terdekat',
        icon: Icons.payments_outlined,
        child: Text('Tagihan belum dapat dimuat. Tarik untuk memuat ulang.'),
      ),
      data: (bills) {
        final next = nearestUnpaidBill(bills);
        if (next == null) {
          return const AppSectionCard(
            title: 'Tagihan Terdekat',
            icon: Icons.payments_outlined,
            child: Text('Tidak ada tagihan terbuka. Semua lunas.'),
          );
        }
        return AppSectionCard(
          title: 'Tagihan Terdekat',
          icon: Icons.payments_outlined,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Periode ${next.billingPeriod}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Jatuh tempo ${formatDateId(next.dueDate)} · ${formatRupiah(next.remaining)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              AppStatusChip(
                label: paymentStatusLabel(next.status),
                tone: paymentTone(next.status),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TenantReportSummary extends StatelessWidget {
  const _TenantReportSummary({required this.reportsAsync});

  final AsyncValue<List<OwnerMaintenanceReport>> reportsAsync;

  @override
  Widget build(BuildContext context) {
    return reportsAsync.when(
      loading: () => const AppSectionCard(
        title: 'Ringkasan Keluhan',
        icon: Icons.handyman_outlined,
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(12),
            child: CircularProgressIndicator(),
          ),
        ),
      ),
      error: (_, _) => const AppSectionCard(
        title: 'Ringkasan Keluhan',
        icon: Icons.handyman_outlined,
        child: Text('Keluhan belum dapat dimuat. Tarik untuk memuat ulang.'),
      ),
      data: (reports) {
        final open = openReportCount(reports);
        return AppSectionCard(
          title: 'Ringkasan Keluhan',
          icon: Icons.handyman_outlined,
          child: Text(
            reports.isEmpty
                ? 'Belum ada laporan. Buat laporan bila ada kendala kamar.'
                : '$open laporan terbuka dari ${reports.length} total laporan.',
          ),
        );
      },
    );
  }
}

class _TenantRecentPayments extends ConsumerWidget {
  const _TenantRecentPayments({required this.myTenant});

  final MyTenant myTenant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final billsAsync = ref.watch(_tenantRecentPaymentsProvider(myTenant));
    return billsAsync.when(
      loading: () => const AppSectionCard(
        title: 'Tagihan Terbaru',
        icon: Icons.payments_outlined,
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(12),
            child: CircularProgressIndicator(),
          ),
        ),
      ),
      error: (error, _) => AppSectionCard(
        title: 'Tagihan Terbaru',
        icon: Icons.payments_outlined,
        child: Text('Tagihan belum dapat dimuat: $error'),
      ),
      data: (list) {
        return AppSectionCard(
          title: 'Tagihan Terbaru',
          icon: Icons.payments_outlined,
          child: list.isEmpty
              ? Text(
                  'Belum ada tagihan tercatat.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                )
              : Column(
                  children: list.take(3).map((p) {
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Periode ${p.billingPeriod}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        'Jatuh tempo: ${formatDateId(p.dueDate)}',
                      ),
                      trailing: AppStatusChip(
                        label: paymentStatusLabel(p.status),
                        tone: paymentTone(p.status),
                      ),
                    );
                  }).toList(),
                ),
        );
      },
    );
  }
}

class _TenantRoomTab extends ConsumerWidget {
  const _TenantRoomTab({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantAsync = ref.watch(currentTenantProvider);
    return tenantAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => AppErrorState(
        message: e.toString(),
        onRetry: () => ref.invalidate(currentTenantProvider),
      ),
      data: (myTenant) {
        if (myTenant == null) {
          return const Center(
            child: AppEmptyState(
              icon: Icons.meeting_room_outlined,
              title: 'Kamar Belum Terdaftar',
              message: 'Hubungi pemilik kos untuk penugasan kamar Anda.',
            ),
          );
        }
        final t = myTenant.tenant;
        final countdown = rentalCountdown(t.endDate);
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            t.roomNumber == null
                                ? 'Kamar Anda'
                                : 'Kamar ${t.roomNumber}',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        AppStatusChip(
                          label: tenantStatusLabel(t.status),
                          tone: tenantTone(t.status),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    _row('Harga Sewa', '${formatRupiah(t.rentPrice ?? 0)} / bulan'),
                    _row('Deposit', formatRupiah(t.deposit ?? 0)),
                    _row('Tanggal Mulai', formatDateId(t.startDate)),
                    _row('Tanggal Berakhir', formatDateId(t.endDate)),
                    _row('Status Sewa', countdown.label),
                    if (t.notes?.isNotEmpty == true)
                      _row('Catatan', t.notes!),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _TenantPaymentsTab extends ConsumerWidget {
  const _TenantPaymentsTab({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantAsync = ref.watch(currentTenantProvider);
    return tenantAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => AppErrorState(
        message: e.toString(),
        onRetry: () => ref.invalidate(currentTenantProvider),
      ),
      data: (myTenant) {
        if (myTenant == null) {
          return const Center(
            child: AppEmptyState(
              icon: Icons.payments_outlined,
              title: 'Belum Ada Tagihan',
              message: 'Data tagihan akan tampil setelah kamar terdaftar.',
            ),
          );
        }
        final billsAsync = ref.watch(
          _tenantRecentPaymentsProvider(myTenant),
        );
        return billsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => AppErrorState(
            message: error.toString(),
            onRetry: () => ref.invalidate(_tenantRecentPaymentsProvider(myTenant)),
          ),
          data: (list) {
            if (list.isEmpty) {
              return const Center(
                child: AppEmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'Belum Ada Riwayat',
                  message: 'Riwayat tagihan Anda kosong.',
                ),
              );
            }
            final open = list.where((p) => p.status != 'paid').length;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: AppSectionCard(
                    title: 'Tagihan Anda',
                    icon: Icons.lock_outline,
                    // ponytail: read-only tenant bills; payment writes stay owner-only.
                    child: Text(
                      '$open tagihan terbuka · ${list.length} total · pembayaran resmi dicatat pemilik kos.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final p = list[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Periode ${p.billingPeriod}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    AppStatusChip(
                                      label: paymentStatusLabel(p.status),
                                      tone: paymentTone(p.status),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Tagihan: ${formatRupiah(p.amountDue)} · Dibayar: ${formatRupiah(p.amountPaid)}',
                                  style: const TextStyle(fontSize: 13),
                                ),
                                Text(
                                  'Jatuh tempo: ${formatDateId(p.dueDate)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                if (p.paymentMethod != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Metode tercatat: ${paymentMethodLabel(p.paymentMethod)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
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

class _TenantMaintenanceTab extends ConsumerWidget {
  const _TenantMaintenanceTab({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantAsync = ref.watch(currentTenantProvider);
    return tenantAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => AppErrorState(
        message: e.toString(),
        onRetry: () => ref.invalidate(currentTenantProvider),
      ),
      data: (myTenant) {
        if (myTenant == null) {
          return const Center(
            child: AppEmptyState(
              icon: Icons.build_outlined,
              title: 'Layanan Belum Tersedia',
              message: 'Layanan bantuan aktif setelah penugasan kamar.',
            ),
          );
        }
        final reportsAsync = ref.watch(_tenantReportsProvider(myTenant.tenant.id));
        return reportsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => AppErrorState(
            message: error.toString(),
            onRetry: () =>
                ref.invalidate(_tenantReportsProvider(myTenant.tenant.id)),
          ),
          data: (list) {
            return Scaffold(
              body: list.isEmpty
                  ? const Center(
                      child: AppEmptyState(
                        icon: Icons.handyman_outlined,
                        title: 'Belum Ada Laporan',
                        message: 'Buat laporan perbaikan bila ada kendala kamar.',
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                      itemCount: list.length,
                      itemBuilder: (context, index) {
                        final r = list[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          r.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      AppStatusChip(
                                        label: maintenanceStatusLabel(r.status),
                                        tone: maintenanceTone(r.status),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    r.description,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Kategori: ${maintenanceCategoryLabel(r.category)} · Prioritas: ${maintenancePriorityLabel(r.priority)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
              floatingActionButton: FloatingActionButton.extended(
                onPressed: () => _openCreateDialog(context, ref, myTenant),
                icon: const Icon(Icons.add),
                label: const Text('Buat Laporan'),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openCreateDialog(
    BuildContext context,
    WidgetRef ref,
    MyTenant myTenant,
  ) async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => TenantReportDialog(myTenant: myTenant),
    );
    if (created == true) {
      ref.invalidate(_tenantReportsProvider(myTenant.tenant.id));
    }
  }
}

/// Extracted dialog so widget tests can verify anti-overflow constraints.
class TenantReportDialog extends ConsumerStatefulWidget {
  const TenantReportDialog({super.key, required this.myTenant});

  final MyTenant myTenant;

  @override
  ConsumerState<TenantReportDialog> createState() => _TenantReportDialogState();
}

class _TenantReportDialogState extends ConsumerState<TenantReportDialog> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  String _category = 'other';
  String _priority = 'medium';
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_title.text.trim().isEmpty || _desc.text.trim().isEmpty) {
      setState(() => _error = 'Judul dan deskripsi wajib diisi.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref
          .read(tenantRepositoryProvider)
          .createReport(
            propertyId: widget.myTenant.propertyId,
            tenantId: widget.myTenant.tenant.id,
            roomId: widget.myTenant.tenant.roomId,
            title: _title.text.trim(),
            description: _desc.text.trim(),
            category: _category,
            priority: _priority,
          );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      setState(() {
        _loading = false;
        _error = 'Gagal menyimpan laporan. Periksa koneksi lalu coba lagi.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: const Text('Lapor Kerusakan'),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 440,
          maxHeight: size.height * 0.7,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Judul keluhan'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _category,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Kategori'),
                items: const [
                  DropdownMenuItem(
                    value: 'AC',
                    child: Text(
                      'AC',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'electrical',
                    child: Text(
                      'Listrik',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'plumbing',
                    child: Text(
                      'Plumbing',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'furniture',
                    child: Text(
                      'Furnitur',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'internet',
                    child: Text(
                      'Internet',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'other',
                    child: Text(
                      'Lainnya',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                onChanged: (v) => setState(() => _category = v ?? 'other'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _priority,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Prioritas'),
                items: const [
                  DropdownMenuItem(
                    value: 'low',
                    child: Text(
                      'Rendah',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'medium',
                    child: Text(
                      'Sedang',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'high',
                    child: Text(
                      'Tinggi',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                onChanged: (v) => setState(() => _priority = v ?? 'medium'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _desc,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Deskripsi keluhan',
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context, false),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _loading ? null : _submit,
          child: Text(_loading ? 'Mengirim...' : 'Kirim'),
        ),
      ],
    );
  }
}

// Keep old name working for existing tests/imports.
typedef TenantWelcome = TenantHome;

/// Canonical settings route used by both shells.
class TenantSettingsRoute extends StatelessWidget {
  const TenantSettingsRoute({super.key});

  @override
  Widget build(BuildContext context) => const SettingsPage();
}
