import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/owner_management.dart';
import '../../../domain/services/owner_display.dart';
import '../application/owner_module_providers.dart';

class RoomsPage extends ConsumerStatefulWidget {
  const RoomsPage({super.key});

  @override
  ConsumerState<RoomsPage> createState() => _RoomsPageState();
}

class _RoomsPageState extends ConsumerState<RoomsPage> {
  String _query = '';
  String _status = 'all';

  Future<void> _openForm({OwnerRoom? room}) async {
    final property = await ref.read(ownerPropertyProvider.future);
    if (!mounted) return;
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _RoomFormDialog(property: property, room: room),
    );
    if (saved == true) setState(() {});
  }

  Future<void> _delete(OwnerRoom room) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Hapus kamar ' + room.roomNumber + '?'),
        content: Text(
          room.tenantName != null
              ? 'Kamar ini masih memiliki penghuni aktif.'
              : 'Data kamar akan dihapus dan tindakan ini tidak dapat dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton.tonal(
            onPressed: room.tenantName != null
                ? null
                : () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(ownerRoomsRepositoryProvider).deleteRoom(room.id);
      setState(() {});
    } catch (error) {
      _showError(error);
    }
  }

  void _showError(Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_friendlyError(error))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(ownerRoomsRepositoryProvider);
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
        return FutureBuilder<List<OwnerRoom>>(
          future: repo.getRooms(
            property.id,
            query: _query,
            status: _status,
          ),
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
            final items = snapshot.data ?? const <OwnerRoom>[];
            return RefreshIndicator(
              onRefresh: () async => setState(() {}),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                children: [
                  Text(
                    'Kelola seluruh kamar ' + property.name + '.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Cari nomor kamar...',
                    ),
                    onChanged: (value) => setState(() => _query = value),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _filter('Semua', 'all'),
                        _filter('Kosong', 'available'),
                        _filter('Terisi', 'occupied'),
                        _filter('Maintenance', 'maintenance'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.icon(
                      onPressed: () => _openForm(),
                      icon: const Icon(Icons.add),
                      label: const Text('Tambah Kamar'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (items.isEmpty)
                    _EmptyState(
                      icon: Icons.meeting_room_outlined,
                      title: 'Belum ada kamar',
                      message: 'Tambahkan kamar pertama Anda.',
                      action: FilledButton.icon(
                        onPressed: () => _openForm(),
                        icon: const Icon(Icons.add),
                        label: const Text('Tambah Kamar'),
                      ),
                    )
                  else
                    ...items.map(
                      (room) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _RoomCard(
                          room: room,
                          onTap: () => _showDetail(room),
                          onEdit: () => _openForm(room: room),
                          onDelete: () => _delete(room),
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

  void _showDetail(OwnerRoom room) {
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
                      'Kamar ' + room.roomNumber,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  _StatusBadge(label: roomStatusLabel(room.status)),
                ],
              ),
              _InfoLine(
                label: 'Harga',
                value: formatRupiah(room.price) + ' / bulan',
              ),
              _InfoLine(
                label: 'Lantai',
                value: room.floor?.toString() ?? '-',
              ),
              _InfoLine(
                label: 'Penghuni',
                value: room.tenantName ?? 'Kosong',
              ),
              _InfoLine(
                label: 'Fasilitas',
                value: room.facilities?.trim().isNotEmpty == true
                    ? room.facilities!
                    : 'Mengikuti fasilitas terdaftar',
              ),
              if (room.notes?.isNotEmpty == true)
                _InfoLine(label: 'Catatan', value: room.notes!),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _openForm(room: room);
                      },
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Ubah'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _delete(room);
                      },
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Hapus'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoomFormDialog extends ConsumerStatefulWidget {
  const _RoomFormDialog({required this.property, this.room});

  final OwnerProperty property;
  final OwnerRoom? room;

  @override
  ConsumerState<_RoomFormDialog> createState() => _RoomFormDialogState();
}

class _RoomFormDialogState extends ConsumerState<_RoomFormDialog> {
  late final TextEditingController _number;
  late final TextEditingController _floor;
  late final TextEditingController _price;
  late final TextEditingController _notes;
  String _status = 'available';
  List<OwnerFacility> _facilities = const [];
  final Set<String> _selected = {};
  String _newFacility = '';
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final room = widget.room;
    _number = TextEditingController(text: room?.roomNumber ?? '');
    _floor = TextEditingController(text: room?.floor?.toString() ?? '');
    _price = TextEditingController(
      text: room?.price.toStringAsFixed(0) ?? '',
    );
    _notes = TextEditingController(text: room?.notes ?? '');
    _status = room?.status ?? 'available';
    _loadFacilities();
  }

  Future<void> _loadFacilities() async {
    try {
      final repo = ref.read(ownerRoomsRepositoryProvider);
      final facilities = await repo.getFacilities(widget.property.id);
      if (widget.room != null) {
        _selected.addAll(
          await repo.getRoomFacilityIds(widget.room!.id),
        );
      }
      if (mounted) {
        setState(() => _facilities = facilities);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _number.dispose();
    _floor.dispose();
    _price.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final number = _number.text.trim();
    final price = num.tryParse(
      _price.text.trim().replaceAll('.', '').replaceAll(',', ''),
    );
    final floor = int.tryParse(_floor.text.trim());

    if (number.isEmpty || price == null || price < 0) {
      setState(() => _error = 'Nomor kamar dan harga sewa wajib valid.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final repo = ref.read(ownerRoomsRepositoryProvider);
      if (widget.room == null) {
        await repo.createRoom(
          widget.property.id,
          roomNumber: number,
          floor: floor,
          price: price,
          status: _status,
          notes: _notes.text,
          facilityIds: _selected.toList(),
        );
      } else {
        await repo.updateRoom(
          widget.room!.id,
          roomNumber: number,
          floor: floor,
          price: price,
          status: _status,
          notes: _notes.text,
          facilityIds: _selected.toList(),
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addFacility() async {
    if (_newFacility.trim().isEmpty) return;
    try {
      final facility = await ref
          .read(ownerRoomsRepositoryProvider)
          .createFacility(widget.property.id, _newFacility);
      setState(() {
        _facilities = [..._facilities, facility]
          ..sort((a, b) => a.name.compareTo(b.name));
        _selected.add(facility.id);
        _newFacility = '';
      });
    } catch (error) {
      setState(() => _error = _friendlyError(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.room == null ? 'Tambah Kamar' : 'Ubah Kamar'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _number,
                decoration: const InputDecoration(
                  labelText: 'Nomor Kamar',
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _floor,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Lantai'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _price,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Harga / bulan',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: const [
                  DropdownMenuItem(
                    value: 'available',
                    child: Text('Kosong'),
                  ),
                  DropdownMenuItem(
                    value: 'occupied',
                    child: Text('Terisi'),
                  ),
                  DropdownMenuItem(
                    value: 'maintenance',
                    child: Text('Maintenance'),
                  ),
                ],
                onChanged: _loading
                    ? null
                    : (value) => setState(() => _status = value!),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Fasilitas',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              ..._facilities.map(
                (facility) => CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(facility.name),
                  value: _selected.contains(facility.id),
                  onChanged: _loading
                      ? null
                      : (checked) => setState(
                            () => checked == true
                                ? _selected.add(facility.id)
                                : _selected.remove(facility.id),
                          ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Tambah fasilitas',
                      ),
                      onChanged: (value) => _newFacility = value,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Tambah fasilitas',
                    onPressed: _loading ? null : _addFacility,
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
              const SizedBox(height: 8),
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

class _RoomCard extends StatelessWidget {
  const _RoomCard({
    required this.room,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final OwnerRoom room;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                child: FittedBox(child: Text(room.roomNumber)),
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
                            'Kamar ' + room.roomNumber,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        _StatusBadge(
                          label: roomStatusLabel(room.status),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      room.tenantName ?? 'Belum ada penghuni',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatRupiah(room.price) +
                          ' / bulan' +
                          (room.floor == null
                              ? ''
                              : ' · Lantai ' + room.floor.toString()),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (room.facilities?.trim().isNotEmpty == true)
                      Text(
                        room.facilities!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') onEdit();
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Ubah')),
                  PopupMenuItem(value: 'delete', child: Text('Hapus')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.circle, size: 7),
          const SizedBox(width: 5),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
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
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 4),
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

String _friendlyError(Object? error) {
  final text = error?.toString().toLowerCase() ?? '';
  if (text.contains('duplicate') || text.contains('unique')) {
    return 'Nomor kamar sudah digunakan.';
  }
  if (text.contains('occupied') || text.contains('active tenant')) {
    return 'Kamar masih memiliki penghuni aktif.';
  }
  if (text.contains('permission') || text.contains('denied')) {
    return 'Akses ke data ini ditolak.';
  }
  return 'Terjadi kesalahan. Silakan coba lagi.';
}
