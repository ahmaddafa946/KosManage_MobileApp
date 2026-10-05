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
                        'Halo, ${profile.name}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Kelola sewa dan tagihan dalam satu tempat.',
                        style: TextStyle(
                          fontSize: 13,
                          color: scheme.onSurfaceVariant,
                        ),
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
              return Column(
                children: [
                  AppSectionCard(
                    title: 'Kamar Anda',
                    icon: Icons.meeting_room_outlined,
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

class _TenantRecentPayments extends ConsumerWidget {
  const _TenantRecentPayments({required this.myTenant});

  final MyTenant myTenant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(tenantRepositoryProvider);
    return FutureBuilder<List<OwnerPayment>>(
      future: repo.getMyPayments(myTenant.propertyId, myTenant.tenant.id),
      builder: (context, snapshot) {
        final list = snapshot.data ?? const [];
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
        final repo = ref.watch(tenantRepositoryProvider);
        return FutureBuilder<List<OwnerPayment>>(
          future: repo.getMyPayments(myTenant.propertyId, myTenant.tenant.id),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final list = snapshot.data ?? const [];
            if (list.isEmpty) {
              return const Center(
                child: AppEmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'Belum Ada Riwayat',
                  message: 'Riwayat tagihan Anda kosong.',
                ),
              );
            }
            return ListView.builder(
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
                              color:
                                  Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
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
        final repo = ref.watch(tenantRepositoryProvider);
        return FutureBuilder<List<OwnerMaintenanceReport>>(
          future: repo.getMyReports(myTenant.tenant.id),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final list = snapshot.data ?? const [];
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
    final title = TextEditingController();
    final desc = TextEditingController();
    String category = 'other';
    String priority = 'medium';
    bool loading = false;
    String? error;

    await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          insetPadding: const EdgeInsets.all(16),
          title: const Text('Lapor Kerusakan'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: title,
                    decoration: const InputDecoration(labelText: 'Judul keluhan'),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: category,
                    decoration: const InputDecoration(labelText: 'Kategori'),
                    items: const [
                      DropdownMenuItem(value: 'AC', child: Text('AC')),
                      DropdownMenuItem(value: 'electrical', child: Text('Listrik')),
                      DropdownMenuItem(value: 'plumbing', child: Text('Plumbing')),
                      DropdownMenuItem(value: 'furniture', child: Text('Furnitur')),
                      DropdownMenuItem(value: 'internet', child: Text('Internet')),
                      DropdownMenuItem(value: 'other', child: Text('Lainnya')),
                    ],
                    onChanged: (v) => setDialogState(() => category = v ?? 'other'),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: priority,
                    decoration: const InputDecoration(labelText: 'Prioritas'),
                    items: const [
                      DropdownMenuItem(value: 'low', child: Text('Rendah')),
                      DropdownMenuItem(value: 'medium', child: Text('Sedang')),
                      DropdownMenuItem(value: 'high', child: Text('Tinggi')),
                    ],
                    onChanged: (v) =>
                        setDialogState(() => priority = v ?? 'medium'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: desc,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Deskripsi keluhan'),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(dialogContext).colorScheme.error,
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
              onPressed: loading ? null : () => Navigator.pop(dialogContext, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: loading
                  ? null
                  : () async {
                      if (title.text.trim().isEmpty ||
                          desc.text.trim().isEmpty) {
                        setDialogState(
                            () => error = 'Judul dan deskripsi wajib diisi.');
                        return;
                      }
                      setDialogState(() {
                        loading = true;
                        error = null;
                      });
                      try {
                        await ref.read(tenantRepositoryProvider).createReport(
                              propertyId: myTenant.propertyId,
                              tenantId: myTenant.tenant.id,
                              roomId: myTenant.tenant.roomId,
                              title: title.text.trim(),
                              description: desc.text.trim(),
                              category: category,
                              priority: priority,
                            );
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext, true);
                        }
                      } catch (e) {
                        setDialogState(() {
                          loading = false;
                          error = 'Gagal menyimpan laporan: $e';
                        });
                      }
                    },
              child: Text(loading ? 'Mengirim...' : 'Kirim'),
            ),
          ],
        ),
      ),
    );
    ref.invalidate(currentTenantProvider);
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
