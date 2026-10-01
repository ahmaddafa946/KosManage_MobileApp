import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/owner_management.dart';
import '../../../domain/services/owner_display.dart';
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
      setState(() {});
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _delete(OwnerTenant tenant) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Hapus ' + tenant.name + '?'),
        content: const Text(
          'Gunakan arsip/nonaktif untuk menjaga histori pembayaran. '
          'Penghapusan permanen sebaiknya hanya untuk data yang memang tidak dibutuhkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ref.read(ownerTenantsRepositoryProvider).deleteTenant(tenant.id);
      setState(() {});
    } catch (error) {
      _showError(error);
    }
  }

  void _showError(Object error) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(_friendlyError(error))));
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(ownerTenantsRepositoryProvider);
    return FutureBuilder<OwnerProperty>(
      future: ref.watch(ownerPropertyProvider.future),
      builder: (context, propertySnapshot) {
        if (propertySnapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (propertySnapshot.hasError || propertySnapshot.data == null) {
          return _ErrorState(
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
              return _ErrorState(
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
                  TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Cari nama atau nomor HP...',
                    ),
                    onChanged: (value) => setState(() => _query = value),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _filter('Semua', 'all'),
                        _filter('Aktif', 'active'),
                        _filter('Tidak aktif', 'inactive'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.icon(
                      onPressed: () => _openForm(),
                      icon: const Icon(Icons.add),
                      label: const Text('Tambah Penghuni'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (items.isEmpty)
                    _EmptyState(
                      icon: Icons.people_outline,
                      title: 'Belum ada penghuni',
                      message:
                          'Tambahkan penghuni dan pilih kamar yang tersedia.',
                      action: FilledButton.icon(
                        onPressed: () => _openForm(),
                        icon: const Icon(Icons.add),
                        label: const Text('Tambah Penghuni'),
                      ),
                    )
                  else
                    ...items.map(
                      (tenant) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
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

  Widget _filter(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
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
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Wrap(
            runSpacing: 12,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      tenant.name,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  _Badge(label: tenantStatusLabel(tenant.status)),
                ],
              ),
              _Line(label: 'Kamar', value: tenant.roomNumber ?? 'Belum ada'),
              _Line(label: 'No. HP', value: tenant.phone ?? '-'),
              _Line(label: 'Email', value: tenant.email ?? '-'),
              _Line(label: 'NIK', value: tenant.identityNumber ?? '-'),
              _Line(label: 'Mulai sewa', value: formatDateId(tenant.startDate)),
              _Line(label: 'Berakhir', value: formatDateId(tenant.endDate)),
              _Line(
                label: 'Countdown',
                value: tenant.status == 'active'
                    ? countdown.label
                    : 'Tidak aktif',
              ),
              _Line(
                label: 'Harga',
                value: formatRupiah(tenant.rentPrice ?? 0) + ' / bulan',
              ),
              _Line(
                label: 'Deposit',
                value: tenant.deposit == null
                    ? '-'
                    : formatRupiah(tenant.deposit!),
              ),
              if (tenant.notes?.isNotEmpty == true)
                _Line(label: 'Catatan', value: tenant.notes!),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _openForm(tenant: tenant);
                      },
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Ubah'),
                    ),
                  ),
                  if (tenant.status == 'active') ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _deactivate(tenant);
                        },
                        icon: const Icon(Icons.person_remove_outlined),
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
    return AlertDialog(
      title: Text(widget.tenant == null ? 'Tambah Penghuni' : 'Ubah Penghuni'),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Nama lengkap'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String?>(
                initialValue: _roomId,
                decoration: const InputDecoration(labelText: 'Kamar'),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Tanpa kamar'),
                  ),
                  ..._rooms.map(
                    (room) => DropdownMenuItem<String?>(
                      value: room.id,
                      child: Text(
                        room.roomNumber +
                            ' · ' +
                            formatRupiah(room.price) +
                            ' / bulan',
                      ),
                    ),
                  ),
                ],
                onChanged: _loading
                    ? null
                    : (value) => setState(() => _roomId = value),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'No. HP'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _identity,
                decoration: const InputDecoration(labelText: 'NIK'),
              ),
              const SizedBox(height: 10),
              Row(
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
              ),
              const SizedBox(height: 10),
              Row(
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
              ),
              const SizedBox(height: 10),
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
                    ),
                  ),
                ),
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
          child: Text(_loading ? 'Menyimpan...' : 'Simpan'),
        ),
      ],
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
    final initial = tenant.name.isEmpty
        ? '?'
        : tenant.name.substring(0, 1).toUpperCase();

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          child: Row(
            children: [
              CircleAvatar(child: Text(initial)),
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
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        _Badge(label: tenantStatusLabel(tenant.status)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tenant.roomNumber == null
                          ? 'Belum ada kamar'
                          : 'Kamar ' + tenant.roomNumber!,
                    ),
                    Text(
                      formatRupiah(tenant.rentPrice ?? 0) +
                          ' / bulan · ' +
                          (tenant.phone ?? '-'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (tenant.status == 'active')
                      Text(
                        countdown.label,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') onEdit();
                  if (value == 'checkout') onDeactivate?.call();
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('Ubah')),
                  if (onDeactivate != null)
                    const PopupMenuItem(
                      value: 'checkout',
                      child: Text('Checkout'),
                    ),
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
        suffixIcon: const Icon(Icons.calendar_today_outlined, size: 19),
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

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 90, child: Text(label)),
        Expanded(child: Text(value)),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    required this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            Icon(icon, size: 44),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 5),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            action,
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

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

String _dateValue(DateTime value) {
  return value.year.toString().padLeft(4, '0') +
      '-' +
      value.month.toString().padLeft(2, '0') +
      '-' +
      value.day.toString().padLeft(2, '0');
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
