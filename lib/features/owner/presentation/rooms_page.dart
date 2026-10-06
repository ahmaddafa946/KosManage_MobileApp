import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/owner_management.dart';
import '../../../domain/services/owner_display.dart';
import '../../shared/presentation/app_ui.dart';
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
    if (saved == true && mounted) setState(() {});
  }

  Future<void> _delete(OwnerRoom room) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Hapus kamar ${room.roomNumber}?'),
        content: Text(
          room.tenantName != null
              ? 'Kamar ini masih memiliki penghuni aktif (${room.tenantName}). Kosongkan terlebih dahulu.'
              : 'Data kamar akan dihapus permanen dari sistem.',
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
    final repo = ref.watch(ownerRoomsRepositoryProvider);
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

        return FutureBuilder<List<OwnerRoom>>(
          future: repo.getRooms(property.id, query: _query, status: _status),
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
            final items = snapshot.data ?? const <OwnerRoom>[];

            return RefreshIndicator(
              onRefresh: () async => setState(() {}),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                children: [
                  // Top Title / Stats Header
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
                              '${items.length} kamar ditemukan',
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
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Tambah'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Search Field
                  AppSearchField(
                    hint: 'Cari nomor kamar...',
                    onChanged: (value) => setState(() => _query = value),
                  ),
                  const SizedBox(height: 12),

                  // Status Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _filterChip('Semua', 'all'),
                        _filterChip('Kosong', 'available'),
                        _filterChip('Terisi', 'occupied'),
                        _filterChip('Maintenance', 'maintenance'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Items List or Empty State
                  if (items.isEmpty)
                    AppEmptyState(
                      icon: Icons.meeting_room_outlined,
                      title: 'Tidak ada kamar',
                      message: _query.isNotEmpty || _status != 'all'
                          ? 'Tidak ada kamar yang sesuai dengan kriteria filter.'
                          : 'Tambahkan kamar pertama untuk memulai operasional kos.',
                      action: FilledButton.icon(
                        onPressed: () => _openForm(),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Tambah Kamar'),
                      ),
                    )
                  else
                    ...items.map(
                      (room) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
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

  Widget _filterChip(String label, String value) {
    final selected = _status == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
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
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Kamar ${room.roomNumber}',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  AppStatusChip(
                    label: roomStatusLabel(room.status),
                    tone: roomTone(room.status),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _DetailRow(
                icon: Icons.attach_money,
                label: 'Harga Sewa',
                value: '${formatRupiah(room.price)} / bulan',
              ),
              _DetailRow(
                icon: Icons.layers_outlined,
                label: 'Posisi Lantai',
                value: room.floor == null ? 'Lantai dasar / tidak diisi' : 'Lantai ${room.floor}',
              ),
              _DetailRow(
                icon: Icons.person_outline,
                label: 'Penghuni Saat Ini',
                value: room.tenantName ?? 'Kamar kosong (Belum terisi)',
              ),
              _DetailRow(
                icon: Icons.wifi,
                label: 'Fasilitas',
                value: room.facilities?.trim().isNotEmpty == true
                    ? room.facilities!
                    : 'Fasilitas standar properti',
              ),
              if (room.notes?.isNotEmpty == true)
                _DetailRow(
                  icon: Icons.notes_outlined,
                  label: 'Catatan',
                  value: room.notes!,
                ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _openForm(room: room);
                      },
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Ubah'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        _delete(room);
                      },
                      icon: const Icon(Icons.delete_outline, size: 18),
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

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: scheme.primary),
          const SizedBox(width: 10),
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
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
    final scheme = Theme.of(context).colorScheme;
    final isOccupied = room.status == 'occupied';

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Room badge avatar
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isOccupied
                      ? scheme.primaryContainer
                      : scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    room.roomNumber,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: isOccupied
                          ? scheme.onPrimaryContainer
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Room info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Kamar ${room.roomNumber}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        AppStatusChip(
                          label: roomStatusLabel(room.status),
                          tone: roomTone(room.status),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      room.tenantName ?? 'Belum ada penghuni',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: room.tenantName != null
                            ? scheme.onSurface
                            : scheme.onSurfaceVariant,
                        fontWeight: room.tenantName != null
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          '${formatRupiah(room.price)} / bln',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: scheme.primary,
                          ),
                        ),
                        if (room.floor != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            '· Lt. ${room.floor}',
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Action popup menu
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, size: 20, color: scheme.onSurfaceVariant),
                onSelected: (value) {
                  if (value == 'edit') onEdit();
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 18),
                        SizedBox(width: 8),
                        Text('Ubah'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, size: 18, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Hapus', style: TextStyle(color: Colors.red)),
                      ],
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
    _price = TextEditingController(text: room?.price.toStringAsFixed(0) ?? '');
    _notes = TextEditingController(text: room?.notes ?? '');
    _status = room?.status ?? 'available';
    _loadFacilities();
  }

  Future<void> _loadFacilities() async {
    try {
      final repo = ref.read(ownerRoomsRepositoryProvider);
      final facilities = await repo.getFacilities(widget.property.id);
      if (widget.room != null) {
        _selected.addAll(await repo.getRoomFacilityIds(widget.room!.id));
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
    final size = MediaQuery.sizeOf(context);
    final dialogWidth = (size.width - 32).clamp(280.0, 500.0).toDouble();
    final dialogHeight = (size.height - 48).clamp(360.0, 620.0).toDouble();

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
                child: Text(widget.room == null ? 'Tambah Kamar' : 'Ubah Kamar'),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _number,
                      decoration: const InputDecoration(labelText: 'Nomor Kamar'),
                    ),
                    const SizedBox(height: 12),
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
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _status,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Status'),
                      items: const [
                        DropdownMenuItem(value: 'available', child: Text('Kosong')),
                        DropdownMenuItem(value: 'occupied', child: Text('Terisi')),
                        DropdownMenuItem(
                          value: 'maintenance',
                          child: Text('Maintenance'),
                        ),
                      ],
                      onChanged: _loading
                          ? null
                          : (value) => setState(() => _status = value!),
                    ),
                    const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Fasilitas Kamar',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    const SizedBox(height: 4),
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
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            decoration: const InputDecoration(
                              hintText: 'Fasilitas baru...',
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
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(widget.room == null ? 'Tambah Kamar' : 'Ubah Kamar'),
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                          child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: _number,
                          decoration: const InputDecoration(labelText: 'Nomor Kamar'),
                        ),
                        const SizedBox(height: 12),
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
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: _status,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Status'),
                          items: const [
                            DropdownMenuItem(value: 'available', child: Text('Kosong')),
                            DropdownMenuItem(value: 'occupied', child: Text('Terisi')),
                            DropdownMenuItem(
                              value: 'maintenance',
                              child: Text('Maintenance'),
                            ),
                          ],
                          onChanged: _loading
                              ? null
                              : (value) => setState(() => _status = value!),
                        ),
                        const SizedBox(height: 14),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Fasilitas Kamar',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                        const SizedBox(height: 4),
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
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                decoration: const InputDecoration(
                                  hintText: 'Fasilitas baru...',
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
