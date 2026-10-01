import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/owner_management.dart';
import '../../../domain/services/owner_display.dart';
import '../../tenant/presentation/payment_form_page.dart';
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
          'Riwayat ini akan dihapus secara permanen. Tindakan tidak dapat dibatalkan.',
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
      await ref.read(ownerPaymentsRepositoryProvider).deletePayment(payment.id);
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
    final paymentsRepo = ref.watch(ownerPaymentsRepositoryProvider);
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
              return _ErrorState(
                message: _friendlyError(snapshot.error),
                onRetry: () => setState(() {}),
              );
            }

            final allItems = snapshot.data ?? const <OwnerPayment>[];
            final query = _query.trim().toLowerCase();
            final items = query.isEmpty
                ? allItems
                : allItems.where((payment) {
                    return (payment.tenantName ?? '')
                            .toLowerCase()
                            .contains(query) ||
                        (payment.roomNumber ?? '')
                            .toLowerCase()
                            .contains(query);
                  }).toList(growable: false);

            return RefreshIndicator(
              onRefresh: () async => setState(() {}),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Cari penghuni atau kamar...',
                    ),
                    onChanged: (value) => setState(() => _query = value),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: TextEditingController(text: _period),
                          keyboardType: TextInputType.datetime,
                          decoration: const InputDecoration(
                            labelText: 'Periode',
                            hintText: 'YYYY-MM',
                          ),
                          onChanged: (value) => _period = value,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Bersihkan periode',
                        onPressed: () => setState(() => _period = ''),
                        icon: const Icon(Icons.clear),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _filter('Semua', 'all', FilterType.status),
                        _filter('Belum', 'unpaid', FilterType.status),
                        _filter('Sebagian', 'partial', FilterType.status),
                        _filter('Lunas', 'paid', FilterType.status),
                        _filter('Terlambat', 'overdue', FilterType.status),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _method,
                    decoration: const InputDecoration(
                      labelText: 'Metode pembayaran',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'all',
                        child: Text('Semua metode'),
                      ),
                      DropdownMenuItem(value: 'cash', child: Text('Cash')),
                      DropdownMenuItem(
                        value: 'transfer',
                        child: Text('Transfer'),
                      ),
                      DropdownMenuItem(
                        value: 'ewallet',
                        child: Text('E-Wallet'),
                      ),
                      DropdownMenuItem(value: 'qris', child: Text('QRIS')),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _method = value);
                    },
                  ),
                  const SizedBox(height: 16),
                  if (items.isEmpty)
                    _EmptyState(
                      icon: Icons.payments_outlined,
                      title: 'Belum ada pembayaran',
                      message:
                          'Catat tagihan atau pembayaran pertama untuk penghuni aktif.',
                      action: FilledButton.icon(
                        onPressed: () => _openForm(),
                        icon: const Icon(Icons.add),
                        label: const Text('Catat Pembayaran'),
                      ),
                    )
                  else
                    ...items.map(
                      (payment) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
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

  Widget _filter(String label, String value, FilterType type) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
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
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Wrap(
            runSpacing: 12,
            children: [
              Text(
                payment.tenantName ?? 'Pembayaran',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              _Line(
                label: 'Kamar',
                value: payment.roomNumber ?? '-',
              ),
              _Line(
                label: 'Periode',
                value: payment.billingPeriod,
              ),
              _Line(
                label: 'Jatuh tempo',
                value: formatDateId(payment.dueDate),
              ),
              _Line(
                label: 'Tagihan',
                value: formatRupiah(payment.amountDue),
              ),
              _Line(
                label: 'Dibayar',
                value: formatRupiah(payment.amountPaid),
              ),
              _Line(
                label: 'Sisa',
                value: formatRupiah(payment.remaining),
              ),
              _Line(
                label: 'Status',
                value: paymentStatusLabel(payment.status),
              ),
              _Line(
                label: 'Metode',
                value: paymentMethodLabel(payment.paymentMethod),
              ),
              _Line(
                label: 'Tanggal bayar',
                value: formatDateId(payment.paymentDate),
              ),
              if (payment.notes?.isNotEmpty == true)
                _Line(label: 'Catatan', value: payment.notes!),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _openForm(payment: payment);
                      },
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Ubah'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _delete(payment);
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

enum FilterType { status }

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
  ConsumerState<_PaymentFormDialog> createState() => _PaymentFormDialogState();
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
    _period = TextEditingController(text: payment?.billingPeriod ?? _monthValue(DateTime.now()));
    _due = TextEditingController(text: payment?.dueDate ?? _dateValue(DateTime.now()));
    _amountDue = TextEditingController(text: payment?.amountDue.toStringAsFixed(0) ?? '');
    _amountPaid = TextEditingController(text: payment?.amountPaid.toStringAsFixed(0) ?? '0');
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
        !RegExp(r'^\\d{4}-\\d{2}$').hasMatch(period) ||
        due.isEmpty ||
        amountDue == null ||
        amountDue < 0 ||
        amountPaid == null ||
        amountPaid < 0) {
      setState(() => _error = 'Lengkapi penghuni, periode, jatuh tempo, dan nominal.');
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
    final tenants = widget.tenants;
    return AlertDialog(
      title: Text(widget.payment == null ? 'Catat Pembayaran' : 'Ubah Pembayaran'),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _tenantId,
                decoration: const InputDecoration(labelText: 'Penghuni'),
                items: tenants
                    .map(
                      (tenant) => DropdownMenuItem(
                        value: tenant.id,
                        child: Text(
                          tenant.name +
                              (tenant.roomNumber == null
                                  ? ''
                                  : ' · Kamar ' + tenant.roomNumber!),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: _loading
                    ? null
                    : (value) => setState(() => _tenantId = value),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _period,
                decoration: const InputDecoration(
                  labelText: 'Periode',
                  hintText: 'YYYY-MM',
                ),
              ),
              const SizedBox(height: 10),
              _DateField(
                label: 'Jatuh tempo',
                controller: _due,
                onTap: () => _pickDate(_due),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _amountDue,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Tagihan',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _amountPaid,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Dibayar',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _DateField(
                label: 'Tanggal bayar',
                controller: _paymentDate,
                onTap: () => _pickDate(_paymentDate),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String?>(
                initialValue: _method,
                decoration: const InputDecoration(labelText: 'Metode'),
                items: const [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Belum dipilih'),
                  ),
                  DropdownMenuItem(
                    value: 'cash',
                    child: Text('Cash'),
                  ),
                  DropdownMenuItem(
                    value: 'transfer',
                    child: Text('Transfer'),
                  ),
                  DropdownMenuItem(
                    value: 'ewallet',
                    child: Text('E-Wallet'),
                  ),
                  DropdownMenuItem(
                    value: 'qris',
                    child: Text('QRIS'),
                  ),
                ],
                onChanged: _loading
                    ? null
                    : (value) => setState(() => _method = value),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _notes,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Catatan'),
              ),
              const SizedBox(height: 8),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Status pembayaran mengikuti perhitungan database.',
                ),
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
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          child: Row(
            children: [
              CircleAvatar(
                child: Icon(
                  payment.status == 'paid'
                      ? Icons.check_rounded
                      : Icons.receipt_long_outlined,
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
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Kamar ' +
                          (payment.roomNumber ?? '-') +
                          ' · ' +
                          payment.billingPeriod,
                    ),
                    Text(
                      formatRupiah(payment.amountPaid) +
                          ' / ' +
                          formatRupiah(payment.amountDue),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      payment.status == 'paid'
                          ? 'Lunas'
                          : 'Sisa ' + formatRupiah(payment.remaining),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _Badge(label: paymentStatusLabel(payment.status)),
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

class _Badge extends StatelessWidget {
  const _Badge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        child: Text(label, style: Theme.of(context).textTheme.labelSmall),
      ),
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
        SizedBox(width: 100, child: Text(label)),
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

String _monthValue(DateTime value) {
  return value.year.toString().padLeft(4, '0') +
      '-' +
      value.month.toString().padLeft(2, '0');
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
