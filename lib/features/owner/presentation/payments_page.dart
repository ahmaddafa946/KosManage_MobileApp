import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/owner_management.dart';
import '../../../domain/services/owner_display.dart';
import '../../shared/presentation/app_ui.dart';
import '../application/owner_module_providers.dart';

class PaymentsPage extends ConsumerStatefulWidget {
  const PaymentsPage({super.key});

  @override
  ConsumerState<PaymentsPage> createState() => _PaymentsPageState();
}

class _PaymentsPageState extends ConsumerState<PaymentsPage> {
  String _period = '';
  String _status = 'all';
  String _method = 'all';
  String _query = '';
  late final TextEditingController _periodController;

  @override
  void initState() {
    super.initState();
    _periodController = TextEditingController();
  }

  @override
  void dispose() {
    _periodController.dispose();
    super.dispose();
  }

  Future<void> _openForm({OwnerPayment? payment}) async {
    final property = await ref.read(ownerPropertyProvider.future);
    final tenants = await ref
        .read(ownerTenantsRepositoryProvider)
        .getTenants(property.id, status: 'active');
    if (!mounted) return;
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _PaymentFormDialog(
        property: property,
        tenants: tenants,
        payment: payment,
      ),
    );
    if (saved == true && mounted) setState(() {});
  }

  Future<void> _delete(OwnerPayment payment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus pembayaran?'),
        content: const Text(
          'Riwayat ini akan dihapus permanen dan tidak bisa dibatalkan.',
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
      await ref.read(ownerPaymentsRepositoryProvider).deletePayment(payment.id);
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
    final paymentsRepo = ref.watch(ownerPaymentsRepositoryProvider);
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
        return FutureBuilder<List<OwnerPayment>>(
          future: paymentsRepo.getPayments(
            property.id,
            billingPeriod: _period,
            status: _status,
            method: _method,
          ),
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

            final allItems = snapshot.data ?? const <OwnerPayment>[];
            final query = _query.trim().toLowerCase();
            final items = query.isEmpty
                ? allItems
                : allItems
                    .where((payment) {
                      return (payment.tenantName ?? '')
                              .toLowerCase()
                              .contains(query) ||
                          (payment.roomNumber ?? '')
                              .toLowerCase()
                              .contains(query);
                    })
                    .toList(growable: false);

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
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${items.length} catatan pembayaran',
                              style: TextStyle(
                                fontSize: 13,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: () => _openForm(),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Catat'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  AppSearchField(
                    hint: 'Cari penghuni atau kamar...',
                    onChanged: (value) => setState(() => _query = value),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _periodController,
                          keyboardType: TextInputType.datetime,
                          decoration: const InputDecoration(
                            labelText: 'Periode',
                            hintText: 'YYYY-MM',
                          ),
                          onChanged: (value) =>
                              setState(() => _period = value.trim()),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Bersihkan periode',
                        onPressed: () {
                          _periodController.clear();
                          setState(() => _period = '');
                        },
                        icon: const Icon(Icons.clear),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _filterChip('Semua', 'all'),
                        _filterChip('Belum', 'unpaid'),
                        _filterChip('Sebagian', 'partial'),
                        _filterChip('Lunas', 'paid'),
                        _filterChip('Terlambat', 'overdue'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _method,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Metode pembayaran',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'all',
                        child: Text('Semua metode',
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      DropdownMenuItem(
                          value: 'cash',
                          child: Text('Cash',
                              maxLines: 1, overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(
                          value: 'transfer',
                          child: Text('Transfer',
                              maxLines: 1, overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(
                          value: 'ewallet',
                          child: Text('E-Wallet',
                              maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _method = value);
                    },
                  ),
                  const SizedBox(height: 16),
                  if (items.isEmpty)
                    AppEmptyState(
                      icon: Icons.payments_outlined,
                      title: 'Belum ada pembayaran',
                      message:
                          'Catat tagihan atau pembayaran pertama untuk penghuni aktif.',
                      action: FilledButton.icon(
                        onPressed: () => _openForm(),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Catat Pembayaran'),
                      ),
                    )
                  else
                    ...items.map(
                      (payment) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _PaymentCard(
                          payment: payment,
                          onTap: () => _showDetail(payment),
                          onEdit: () => _openForm(payment: payment),
                          onDelete: () => _delete(payment),
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

  void _showDetail(OwnerPayment payment) {
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
                      payment.tenantName ?? 'Pembayaran',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AppStatusChip(
                    label: paymentStatusLabel(payment.status),
                    tone: paymentTone(payment.status),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _DetailRow(
                  label: 'Kamar',
                  value: payment.roomNumber == null
                      ? '-'
                      : 'Kamar ${payment.roomNumber}'),
              _DetailRow(label: 'Periode', value: payment.billingPeriod),
              _DetailRow(
                  label: 'Jatuh tempo',
                  value: formatDateId(payment.dueDate)),
              _DetailRow(
                  label: 'Tagihan',
                  value: formatRupiah(payment.amountDue)),
              _DetailRow(
                  label: 'Dibayar',
                  value: formatRupiah(payment.amountPaid)),
              _DetailRow(
                  label: 'Sisa', value: formatRupiah(payment.remaining)),
              _DetailRow(
                label: 'Metode',
                value: paymentMethodLabel(payment.paymentMethod),
              ),
              _DetailRow(
                label: 'Tanggal bayar',
                value: formatDateId(payment.paymentDate),
              ),
              if (payment.notes?.isNotEmpty == true)
                _DetailRow(label: 'Catatan', value: payment.notes!),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _openForm(payment: payment);
                      },
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Ubah'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor:
                            Theme.of(context).colorScheme.error,
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        _delete(payment);
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

class _PaymentFormDialog extends ConsumerStatefulWidget {
  const _PaymentFormDialog({
    required this.property,
    required this.tenants,
    this.payment,
  });

  final OwnerProperty property;
  final List<OwnerTenant> tenants;
  final OwnerPayment? payment;

  @override
  ConsumerState<_PaymentFormDialog> createState() =>
      _PaymentFormDialogState();
}

class _PaymentFormDialogState extends ConsumerState<_PaymentFormDialog> {
  late final TextEditingController _period;
  late final TextEditingController _due;
  late final TextEditingController _amountDue;
  late final TextEditingController _amountPaid;
  late final TextEditingController _paymentDate;
  late final TextEditingController _notes;

  String? _tenantId;
  String? _method;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final payment = widget.payment;
    _period = TextEditingController(
      text: payment?.billingPeriod ?? _monthValue(DateTime.now()),
    );
    _due = TextEditingController(
      text: payment?.dueDate ?? _dateValue(DateTime.now()),
    );
    _amountDue = TextEditingController(
      text: payment?.amountDue.toStringAsFixed(0) ?? '',
    );
    _amountPaid = TextEditingController(
      text: payment?.amountPaid.toStringAsFixed(0) ?? '0',
    );
    _paymentDate = TextEditingController(text: payment?.paymentDate ?? '');
    _notes = TextEditingController(text: payment?.notes ?? '');
    _tenantId = payment?.tenantId;
    _method = payment?.paymentMethod;
  }

  @override
  void dispose() {
    _period.dispose();
    _due.dispose();
    _amountDue.dispose();
    _amountPaid.dispose();
    _paymentDate.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate(TextEditingController controller) async {
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
    final tenantId = _tenantId;
    final period = _period.text.trim();
    final due = _due.text.trim();
    final amountDue = num.tryParse(
      _amountDue.text.trim().replaceAll('.', '').replaceAll(',', ''),
    );
    final amountPaid = num.tryParse(
      _amountPaid.text.trim().replaceAll('.', '').replaceAll(',', ''),
    );

    if (tenantId == null ||
        !RegExp(r'^\d{4}-\d{2}$').hasMatch(period) ||
        due.isEmpty ||
        amountDue == null ||
        amountDue < 0 ||
        amountPaid == null ||
        amountPaid < 0) {
      setState(
        () => _error =
            'Lengkapi penghuni, periode, jatuh tempo, dan nominal.',
      );
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final repo = ref.read(ownerPaymentsRepositoryProvider);
      if (widget.payment == null) {
        await repo.createPayment(
          widget.property.id,
          tenantId: tenantId,
          billingPeriod: period,
          dueDate: due,
          amountDue: amountDue,
          amountPaid: amountPaid,
          paymentDate: _paymentDate.text.trim(),
          paymentMethod: _method,
          notes: _notes.text,
        );
      } else {
        await repo.updatePayment(
          widget.payment!.id,
          tenantId: tenantId,
          billingPeriod: period,
          dueDate: due,
          amountDue: amountDue,
          amountPaid: amountPaid,
          paymentDate: _paymentDate.text.trim(),
          paymentMethod: _method,
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
                child: Text(
                  widget.payment == null ? 'Catat Pembayaran' : 'Ubah Pembayaran',
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OwnerTenantDropdownField(
                      tenants: widget.tenants,
                      value: _tenantId,
                      enabled: !_loading,
                      onChanged: (value) => setState(() => _tenantId = value),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _period,
                      decoration: const InputDecoration(
                        labelText: 'Periode',
                        hintText: 'YYYY-MM',
                      ),
                    ),
                    const SizedBox(height: 12),
                    _DateField(
                      label: 'Jatuh tempo',
                      controller: _due,
                      onTap: () => _pickDate(_due),
                    ),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth < 340) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextField(
                                controller: _amountDue,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                    labelText: 'Tagihan (Rp)'),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _amountPaid,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                    labelText: 'Dibayar (Rp)'),
                              ),
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _amountDue,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                    labelText: 'Tagihan (Rp)'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: _amountPaid,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                    labelText: 'Dibayar (Rp)'),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    _DateField(
                      label: 'Tanggal bayar (opsional)',
                      controller: _paymentDate,
                      onTap: () => _pickDate(_paymentDate),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _method,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Metode'),
                      items: const [
                        DropdownMenuItem<String>(
                          value: null,
                          child: Text('Belum dipilih',
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                        DropdownMenuItem(
                            value: 'cash',
                            child: Text('Cash',
                                maxLines: 1, overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(
                            value: 'transfer',
                            child: Text('Transfer',
                                maxLines: 1, overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(
                            value: 'ewallet',
                            child: Text('E-Wallet',
                                maxLines: 1, overflow: TextOverflow.ellipsis)),
                      ],
                      onChanged: _loading
                          ? null
                          : (value) => setState(() => _method = value),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _notes,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Catatan'),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Status dihitung otomatis dari nominal.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
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
                          child: Text(
                  widget.payment == null ? 'Catat Pembayaran' : 'Ubah Pembayaran',
                ),
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                          child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        OwnerTenantDropdownField(
                          tenants: widget.tenants,
                          value: _tenantId,
                          enabled: !_loading,
                          onChanged: (value) => setState(() => _tenantId = value),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _period,
                          decoration: const InputDecoration(
                            labelText: 'Periode',
                            hintText: 'YYYY-MM',
                          ),
                        ),
                        const SizedBox(height: 12),
                        _DateField(
                          label: 'Jatuh tempo',
                          controller: _due,
                          onTap: () => _pickDate(_due),
                        ),
                        const SizedBox(height: 12),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            if (constraints.maxWidth < 340) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  TextField(
                                    controller: _amountDue,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                        labelText: 'Tagihan (Rp)'),
                                  ),
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: _amountPaid,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                        labelText: 'Dibayar (Rp)'),
                                  ),
                                ],
                              );
                            }
                            return Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _amountDue,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                        labelText: 'Tagihan (Rp)'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextField(
                                    controller: _amountPaid,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                        labelText: 'Dibayar (Rp)'),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        _DateField(
                          label: 'Tanggal bayar (opsional)',
                          controller: _paymentDate,
                          onTap: () => _pickDate(_paymentDate),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: _method,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Metode'),
                          items: const [
                            DropdownMenuItem<String>(
                              value: null,
                              child: Text('Belum dipilih',
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                            ),
                            DropdownMenuItem(
                                value: 'cash',
                                child: Text('Cash',
                                    maxLines: 1, overflow: TextOverflow.ellipsis)),
                            DropdownMenuItem(
                                value: 'transfer',
                                child: Text('Transfer',
                                    maxLines: 1, overflow: TextOverflow.ellipsis)),
                            DropdownMenuItem(
                                value: 'ewallet',
                                child: Text('E-Wallet',
                                    maxLines: 1, overflow: TextOverflow.ellipsis)),
                          ],
                          onChanged: _loading
                              ? null
                              : (value) => setState(() => _method = value),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _notes,
                          maxLines: 2,
                          decoration: const InputDecoration(labelText: 'Catatan'),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Status dihitung otomatis dari nominal.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
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

/// Root overflow fix: selected display + menu item both constrained.
/// Old code only set ellipsis on menu item; selected value Row
/// could push 47px beyond 280px dialog. isExpanded + selectedItemBuilder
/// forces tight layout. ponytail: switch to search field when >50 tenants.
class OwnerTenantDropdownField extends StatelessWidget {
  const OwnerTenantDropdownField({
    super.key,
    required this.tenants,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final List<OwnerTenant> tenants;
  final String? value;
  final bool enabled;
  final ValueChanged<String?> onChanged;

  String _label(OwnerTenant t) =>
      t.roomNumber == null ? t.name : '${t.name} · Kamar ${t.roomNumber}';

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Penghuni'),
      hint: const Text('Pilih penghuni',
          maxLines: 1, overflow: TextOverflow.ellipsis),
      selectedItemBuilder: (context) => tenants
          .map(
            (t) => Text(
              _label(t),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          )
          .toList(),
      items: tenants
          .map(
            (tenant) => DropdownMenuItem(
              value: tenant.id,
              child: Text(
                _label(tenant),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: enabled ? onChanged : null,
    );
  }
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({
    required this.payment,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final OwnerPayment payment;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isPaid = payment.status == 'paid';

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isPaid
                      ? const Color(0xFF10B981).withValues(alpha: 0.15)
                      : scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isPaid
                      ? Icons.check_rounded
                      : Icons.receipt_long_outlined,
                  size: 22,
                  color: isPaid
                      ? const Color(0xFF047857)
                      : scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      payment.tenantName ?? 'Penghuni',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Kamar ${payment.roomNumber ?? '-'} · ${payment.billingPeriod}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12, color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${formatRupiah(payment.amountPaid)} / ${formatRupiah(payment.amountDue)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isPaid
                          ? 'Lunas'
                          : 'Sisa ${formatRupiah(payment.remaining)} · Jatuh tempo ${formatDateId(payment.dueDate)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11, color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppStatusChip(
                    label: paymentStatusLabel(payment.status),
                    tone: paymentTone(payment.status),
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert,
                        size: 20, color: scheme.onSurfaceVariant),
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
            width: 110,
            child: Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurfaceVariant)),
          ),
          Expanded(
            child: Text(value,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

String _dateValue(DateTime value) {
  return '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}

String _monthValue(DateTime value) {
  return '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}';
}

String _friendlyError(Object? error) {
  final text = error?.toString().toLowerCase() ?? '';
  if (text.contains('unique') || text.contains('duplicate')) {
    return 'Pembayaran untuk periode tersebut mungkin sudah tercatat.';
  }
  if (text.contains('negative')) {
    return 'Nominal pembayaran tidak boleh negatif.';
  }
  if (text.contains('permission') || text.contains('denied')) {
    return 'Akses ke data ini ditolak.';
  }
  return 'Terjadi kesalahan. Silakan coba lagi.';
}
