import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/models/owner_management.dart';
import '../../../domain/services/owner_display.dart';
import '../application/tenant_payment_providers.dart';
import 'tenant_shell_page.dart'; // For tenantRepositoryProvider

class PaymentSelectionSheet extends ConsumerStatefulWidget {
  const PaymentSelectionSheet({super.key, required this.invoice});
  final OwnerPayment invoice;

  @override
  ConsumerState<PaymentSelectionSheet> createState() => _PaymentSelectionSheetState();
}

class _PaymentSelectionSheetState extends ConsumerState<PaymentSelectionSheet> {
  String _selectedMethod = 'qris';
  String? _selectedBank;
  bool _isLoading = false;

  Future<void> _submit() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(tenantRepositoryProvider);
      
      Map<String, dynamic> result;
      if (_selectedMethod == 'cash') {
        result = await repo.createCashPayment(invoiceId: widget.invoice.id);
      } else {
        result = await repo.createPaymentIntent(
          invoiceId: widget.invoice.id,
          paymentMethod: _selectedMethod,
          bank: _selectedMethod == 'bank_transfer' ? _selectedBank : null,
        );
      }

      if (mounted) {
        Navigator.pop(context, result);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Pilih Metode Pembayaran',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Tagihan: ${formatRupiah(widget.invoice.remaining)}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            RadioGroup<String>(
              groupValue: _selectedMethod,
              onChanged: (value) {
                if (value == null) return;

                setState(() {
                  _selectedMethod = value;
                  _selectedBank = value == 'bank_transfer' ? 'bca' : null;
                });
              },
              child: Column(
                children: [
                  RadioListTile<String>(
                    title: const Text('QRIS (Otomatis)'),
                    subtitle: const Text('Bayar dengan GoPay, OVO, Dana, dll'),
                    value: 'qris',
                  ),
                  RadioListTile<String>(
                    title: const Text('Transfer Bank (Virtual Account)'),
                    value: 'bank_transfer',
                  ),
                  if (_selectedMethod == 'bank_transfer')
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 8,
                      ),
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedBank,
                        decoration: const InputDecoration(
                          labelText: 'Pilih Bank',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'bca',
                            child: Text('BCA Virtual Account'),
                          ),
                          DropdownMenuItem(
                            value: 'bni',
                            child: Text('BNI Virtual Account'),
                          ),
                          DropdownMenuItem(
                            value: 'bri',
                            child: Text('BRI Virtual Account'),
                          ),
                          DropdownMenuItem(
                            value: 'mandiri',
                            child: Text('Mandiri Virtual Account'),
                          ),
                          DropdownMenuItem(
                            value: 'permata',
                            child: Text('Permata Virtual Account'),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() => _selectedBank = value);
                        },
                      ),
                    ),
                  RadioListTile<String>(
                    title: const Text('Tunai (Cash)'),
                    subtitle: const Text(
                      'Bayar langsung ke pemilik/pengurus',
                    ),
                    value: 'cash',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isLoading ? null : _submit,
              child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Lanjutkan Pembayaran'),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class ActiveTransactionScreen extends ConsumerStatefulWidget {
  const ActiveTransactionScreen({super.key, required this.transactionId});
  final String transactionId;

  @override
  ConsumerState<ActiveTransactionScreen> createState() => _ActiveTransactionScreenState();
}

class _ActiveTransactionScreenState extends ConsumerState<ActiveTransactionScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stream = ref.watch(paymentTransactionRealtimeProvider(widget.transactionId));

    return Scaffold(
      appBar: AppBar(title: const Text('Pembayaran')),
      body: stream.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (tx) {
          if (tx == null) return const Center(child: Text('Transaksi tidak ditemukan'));

          if (tx.status == 'success') {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 80),
                  const SizedBox(height: 24),
                  const Text('Pembayaran Berhasil!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () {
                      refreshTenantPaymentData(ref);
                      context.go('/home');
                    },
                    child: const Text('Kembali ke Beranda'),
                  ),
                ],
              ),
            );
          }

          if (tx.status == 'failed' || tx.status == 'expired' || tx.status == 'cancelled' || tx.isExpired) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.cancel, color: Colors.red, size: 80),
                  const SizedBox(height: 24),
                  const Text('Pembayaran Gagal/Kedaluwarsa', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () {
                      refreshTenantPaymentData(ref);
                      context.go('/home');
                    },
                    child: const Text('Kembali'),
                  ),
                ],
              ),
            );
          }

          // Format expiration time
          String expStr = '';
          if (tx.expiresAt != null) {
            final exp = DateTime.parse(tx.expiresAt!);
            final diff = exp.difference(DateTime.now());
            if (diff.isNegative) {
              expStr = 'Waktu Habis';
            } else {
              expStr = '${diff.inHours.toString().padLeft(2, '0')}:${(diff.inMinutes % 60).toString().padLeft(2, '0')}:${(diff.inSeconds % 60).toString().padLeft(2, '0')}';
            }
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Order ID: ${tx.orderId}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const Text('Total Pembayaran', style: TextStyle(fontSize: 14)),
                        const SizedBox(height: 8),
                        Text(
                          formatRupiah(tx.grossAmount),
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 24),
                        if (tx.paymentMethod == 'qris' && tx.qrUrl != null) ...[
                          const Text('Scan QRIS', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 16),
                          Image.network(tx.qrUrl!, height: 250, width: 250, fit: BoxFit.contain, errorBuilder: (c, e, s) => const Icon(Icons.qr_code, size: 200)),
                        ] else if (tx.paymentMethod == 'bank_transfer') ...[
                          Text('Transfer ke Virtual Account ${tx.bank?.toUpperCase()}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(16),
                            color: Colors.grey.shade200,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(tx.vaNumber ?? '-', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2)),
                                const SizedBox(width: 8),
                                const Icon(Icons.copy, size: 20),
                              ],
                            ),
                          ),
                        ] else if (tx.paymentMethod == 'cash') ...[
                          const Icon(Icons.money, size: 80, color: Colors.green),
                          const SizedBox(height: 16),
                          const Text('Silakan serahkan uang tunai kepada pemilik/pengurus kos.', textAlign: TextAlign.center),
                          const SizedBox(height: 8),
                          const Text('Status akan berubah otomatis setelah dikonfirmasi.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                        ],
                        const SizedBox(height: 32),
                        const Text('Batas Waktu Pembayaran', style: TextStyle(color: Colors.red)),
                        const SizedBox(height: 8),
                        Text(expStr, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.red)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                OutlinedButton(
                  onPressed: () {
                    // Just navigate back, transaction stays pending
                    context.go('/home');
                  },
                  child: const Text('Bayar Nanti (Kembali ke Beranda)'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
