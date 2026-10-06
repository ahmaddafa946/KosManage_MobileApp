import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/owner_management.dart';
import '../../../domain/services/owner_display.dart';
import '../../shared/presentation/app_ui.dart';
import '../application/owner_module_providers.dart';

class TenantsPage extends ConsumerStatefulWidget {
  const TenantsPage({super.key});

  @override
  ConsumerState<TenantsPage> createState() => _TenantsPageState();
}

class _TenantsPageState extends ConsumerState<TenantsPage> {
  String _query = '';
  String _status = 'all';

  Future<void> _openForm({OwnerTenant? tenant}) async {
    final property = await ref.read(ownerPropertyProvider.future);
    if (!mounted) return;
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _TenantFormDialog(property: property, tenant: tenant),
    );
    if (saved == true && mounted) setState(() {});
  }

  Future<void> _deactivate(OwnerTenant tenant) async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: DateTime.now(),
      helpText: 'Tanggal checkout',
    );
    if (date == null || !mounted) return;

    try {
      await ref
          .read(ownerTenantsRepositoryProvider)
          .deactivateTenant(tenant.id, endDate: _dateValue(date));
      if (mounted) setState(() {});
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _delete(OwnerTenant tenant) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Hapus ${tenant.name}?'),
        content: const Text(
          'Hapus permanen akan menghilangkan riwayat penghuni. '
          'Gunakan Checkout untuk menonaktifkan dengan aman.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ref.read(ownerTenantsRepositoryProvider).deleteTenant(tenant.id);
      if (mounted) setState(() {});
    } catch (error) {
      _showError(error);
    }
  }

  void _showError(Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_friendlyError(error)),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(ownerTenantsRepositoryProvider);
    final scheme = Theme.of(context).colorScheme;

    return FutureBuilder<OwnerProperty>(
      future: ref.watch(ownerPropertyProvider.future),
      builder: (context, propertySnapshot) {
        if (propertySnapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (propertySnapshot.hasError || propertySnapshot.data == null) {
          return AppErrorState(
            message: _friendlyError(propertySnapshot.error),
            onRetry: () => setState(() {}),
          );
        }
        final property = propertySnapshot.data!;
        return FutureBuilder<List<OwnerTenant>>(
          future: repo.getTenants(property.id, query: _query, status: _status),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return AppErrorState(
                message: _friendlyError(snapshot.error),
                onRetry: () => setState(() {}),
              );
            }

            final items = snapshot.data ?? const <OwnerTenant>[];
            return RefreshIndicator(
              onRefresh: () async => setState(() {}),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              property.name,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${items.length} penghuni ditemukan',
                              style: TextStyle(
                                fontSize: 13,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: () => _openForm(),
                        icon: const Icon(Icons.person_add_outlined, size: 18),
                        label: const Text('Tambah'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  AppSearchField(
                    hint: 'Cari nama atau nomor HP...',
                    onChanged: (value) => setState(() => _query = value),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _filterChip('Semua', 'all'),
                        _filterChip('Aktif', 'active'),
                        _filterChip('Tidak aktif', 'inactive'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (items.isEmpty)
                    AppEmptyState(
                      icon: Icons.people_outline,
                      title: 'Tidak ada penghuni',
                      message: _query.isNotEmpty || _status != 'all'
                          ? 'Tidak ada penghuni sesuai filter saat ini.'
                          : 'Tambahkan penghuni dan tempatkan ke kamar kosong.',
                      action: FilledButton.icon(
                        onPressed: () => _openForm(),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Tambah Penghuni'),
                      ),
                    )
                  else
                    ...items.map(
                      (tenant) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _TenantCard(
                          tenant: tenant,
                          onTap: () => _showDetail(tenant),
                          onEdit: () => _openForm(tenant: tenant),
                          onDeactivate: tenant.status == 'active'
                              ? () => _deactivate(tenant)
                              : null,
                          onDelete: () => _delete(tenant),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _filterChip(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: _status == value,
        onSelected: (_) => setState(() => _status = value),
      ),
    );
  }

  void _showDetail(OwnerTenant tenant) {
    final countdown = rentalCountdown(tenant.endDate);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      tenant.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AppStatusChip(
                    label: tenantStatusLabel(tenant.status),
                    tone: tenantTone(tenant.status),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _DetailRow(label: 'Kamar', value: tenant.roomNumber == null ? 'Belum ditempatkan' : 'Kamar ${tenant.roomNumber}'),
              _DetailRow(label: 'No. HP', value: tenant.phone ?? '-'),
              _DetailRow(label: 'Email', value: tenant.email ?? '-'),
              _DetailRow(label: 'NIK', value: tenant.identityNumber ?? '-'),
              _DetailRow(label: 'Mulai sewa', value: formatDateId(tenant.startDate)),
              _DetailRow(label: 'Berakhir', value: formatDateId(tenant.endDate)),
              _DetailRow(
                label: 'Sisa sewa',
                value: tenant.status == 'active' ? countdown.label : 'Tidak aktif',
              ),
              _DetailRow(
                label: 'Harga',
                value: '${formatRupiah(tenant.rentPrice ?? 0)} / bulan',
              ),
              _DetailRow(
                label: 'Deposit',
                value: tenant.deposit == null ? '-' : formatRupiah(tenant.deposit!),
              ),
              if (tenant.notes?.isNotEmpty == true)
                _DetailRow(label: 'Catatan', value: tenant.notes!),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _openForm(tenant: tenant);
                      },
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Ubah'),
                    ),
                  ),
                  if (tenant.status == 'active') ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _deactivate(tenant);
                        },
                        icon: const Icon(Icons.person_remove_outlined, size: 18),
                        label: const Text('Checkout'),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 95,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _TenantFormDialog extends ConsumerStatefulWidget {
  const _TenantFormDialog({required this.property, this.tenant});

  final OwnerProperty property;
  final OwnerTenant? tenant;

  @override
  ConsumerState<_TenantFormDialog> createState() => _TenantFormDialogState();
}

class _TenantFormDialogState extends ConsumerState<_TenantFormDialog> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _identity;
  late final TextEditingController _start;
  late final TextEditingController _end;
  late final TextEditingController _rent;
  late final TextEditingController _deposit;
  late final TextEditingController _notes;

  List<OwnerRoom> _rooms = const [];
  String? _roomId;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final tenant = widget.tenant;
    _name = TextEditingController(text: tenant?.name ?? '');
    _phone = TextEditingController(text: tenant?.phone ?? '');
    _email = TextEditingController(text: tenant?.email ?? '');
    _identity = TextEditingController(text: tenant?.identityNumber ?? '');
    _start = TextEditingController(
      text: tenant?.startDate ?? _dateValue(DateTime.now()),
    );
    _end = TextEditingController(text: tenant?.endDate ?? '');
    _rent = TextEditingController(
      text: tenant?.rentPrice?.toStringAsFixed(0) ?? '',
    );
    _deposit = TextEditingController(
      text: tenant?.deposit?.toStringAsFixed(0) ?? '',
    );
    _notes = TextEditingController(text: tenant?.notes ?? '');
    _roomId = tenant?.roomId;
    _loadRooms();
  }

  Future<void> _loadRooms() async {
    try {
      final rooms = await ref
          .read(ownerTenantsRepositoryProvider)
          .getAvailableRooms(
            widget.property.id,
            currentRoomId: widget.tenant?.roomId,
          );
      if (mounted) setState(() => _rooms = rooms);
    } catch (_) {}
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _identity.dispose();
    _start.dispose();
    _end.dispose();
    _rent.dispose();
    _deposit.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pick(TextEditingController controller) async {
    final current = DateTime.tryParse(controller.text) ?? DateTime.now();
    final value = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: current,
    );
    if (value != null) controller.text = _dateValue(value);
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    final rent = num.tryParse(
      _rent.text.trim().replaceAll('.', '').replaceAll(',', ''),
    );
    final deposit =
        num.tryParse(
          _deposit.text.trim().replaceAll('.', '').replaceAll(',', ''),
        ) ??
        0;

    if (name.isEmpty ||
        rent == null ||
        rent < 0 ||
        _start.text.trim().isEmpty) {
      setState(
        () => _error = 'Nama, tanggal mulai, dan harga sewa wajib valid.',
      );
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final repo = ref.read(ownerTenantsRepositoryProvider);
      if (widget.tenant == null) {
        await repo.createTenant(
          widget.property.id,
          name: name,
          roomId: _roomId,
          phone: _phone.text,
          email: _email.text,
          identityNumber: _identity.text,
          startDate: _start.text.trim(),
          endDate: _end.text.trim(),
          rentPrice: rent,
          deposit: deposit,
          notes: _notes.text,
        );
      } else {
        await repo.updateTenant(
          widget.tenant!.id,
          name: name,
          roomId: _roomId,
          phone: _phone.text,
          email: _email.text,
          identityNumber: _identity.text,
          startDate: _start.text.trim(),
          endDate: _end.text.trim(),
          rentPrice: rent,
          deposit: deposit,
          notes: _notes.text,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final dialogWidth = (size.width - 32).clamp(280.0, 500.0).toDouble();
    final dialogHeight =
        (size.height - viewInsets.bottom - 48).clamp(280.0, 620.0).toDouble();

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: SizedBox(
        width: dialogWidth,
        height: dialogHeight,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(widget.tenant == null ? 'Tambah Penghuni' : 'Ubah Penghuni'),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _name,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Nama lengkap'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      initialValue: _roomId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Kamar'),
                      selectedItemBuilder: (context) => [
                        const Text('Tanpa kamar', maxLines: 1, overflow: TextOverflow.ellipsis),
                        ..._rooms.map(
                          (room) => Text(
                            '${room.roomNumber} · ${formatRupiah(room.price)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Tanpa kamar', maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                        ..._rooms.map(
                          (room) => DropdownMenuItem<String>(
                            value: room.id,
                            child: Text(
                              '${room.roomNumber} · ${formatRupiah(room.price)} / bulan',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: _loading
                          ? null
                          : (value) => setState(() => _roomId = value),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'No. HP'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _identity,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'NIK'),
                    ),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final narrow = constraints.maxWidth < 340;
                        if (narrow) {
                          return Column(
                            children: [
                              _DateField(label: 'Mulai sewa', controller: _start, onTap: () => _pick(_start)),
                              const SizedBox(height: 12),
                              _DateField(label: 'Berakhir (opsional)', controller: _end, onTap: () => _pick(_end)),
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(
                              child: _DateField(
                                label: 'Mulai sewa',
                                controller: _start,
                                onTap: () => _pick(_start),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _DateField(
                                label: 'Berakhir',
                                controller: _end,
                                onTap: () => _pick(_end),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth < 340) {
                          return Column(
                            children: [
                              TextField(controller: _rent, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Harga sewa / bulan')),
                              const SizedBox(height: 12),
                              TextField(controller: _deposit, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Deposit')),
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _rent,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Harga sewa / bulan',
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: _deposit,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(labelText: 'Deposit'),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _notes,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Catatan'),
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _loading ? null : () => Navigator.pop(context, false),
                    child: const Text('Batal'),
                  ),
                  FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: Text(_loading ? 'Menyimpan...' : 'Simpan'),
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

class _TenantCard extends StatelessWidget {
  const _TenantCard({
    required this.tenant,
    required this.onTap,
    required this.onEdit,
    required this.onDeactivate,
    required this.onDelete,
  });

  final OwnerTenant tenant;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback? onDeactivate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final countdown = rentalCountdown(tenant.endDate);
    final scheme = Theme.of(context).colorScheme;
    final initial = tenant.name.isEmpty ? '?' : tenant.name.substring(0, 1).toUpperCase();

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: scheme.primaryContainer,
                child: Text(
                  initial,
                  style: TextStyle(fontWeight: FontWeight.w800, color: scheme.onPrimaryContainer),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            tenant.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 8),
                        AppStatusChip(label: tenantStatusLabel(tenant.status), tone: tenantTone(tenant.status)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tenant.roomNumber == null ? 'Belum ada kamar' : 'Kamar ${tenant.roomNumber}',
                      style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${formatRupiah(tenant.rentPrice ?? 0)} / bln · ${tenant.phone ?? '-'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                    if (tenant.status == 'active') ...[
                      const SizedBox(height: 4),
                      Text(
                        countdown.label,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: scheme.primary),
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, size: 20, color: scheme.onSurfaceVariant),
                onSelected: (value) {
                  if (value == 'edit') onEdit();
                  if (value == 'checkout') onDeactivate?.call();
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('Ubah')),
                  if (onDeactivate != null)
                    const PopupMenuItem(value: 'checkout', child: Text('Checkout')),
                  const PopupMenuItem(value: 'delete', child: Text('Hapus')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.controller,
    required this.onTap,
  });

  final String label;
  final TextEditingController controller;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      readOnly: true,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
      ),
    );
  }
}

String _dateValue(DateTime value) {
  return '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}

String _friendlyError(Object? error) {
  final text = error?.toString().toLowerCase() ?? '';
  if (text.contains('occupied') || text.contains('room')) {
    return 'Kamar tidak tersedia. Pilih kamar kosong lainnya.';
  }
  if (text.contains('unique') || text.contains('duplicate')) {
    return 'Data dengan kombinasi tersebut sudah ada.';
  }
  if (text.contains('permission') || text.contains('denied')) {
    return 'Akses ke data ini ditolak.';
  }
  return 'Terjadi kesalahan. Silakan coba lagi.';
}
