import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/payment_transaction.dart';
import '../../../domain/services/owner_display.dart';
import '../../shared/presentation/app_ui.dart';
import '../application/owner_module_providers.dart';

class CashConfirmationPage extends ConsumerStatefulWidget {
  const CashConfirmationPage({super.key});

  @override
  ConsumerState<CashConfirmationPage> createState() => _CashConfirmationPageState();
}

class _CashConfirmationPageState extends ConsumerState<CashConfirmationPage> {
  bool _isLoading = false;

  Future<void> _confirmPayment(PaymentTransaction tx, String status) async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(ownerPaymentsRepositoryProvider);
      await repo.confirmCashPayment(tx.id, status);
      ref.invalidate(ownerPendingCashTransactionsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(status == 'success' ? 'Pembayaran diterima.' : 'Pembayaran ditolak.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingAsync = ref.watch(ownerPendingCashTransactionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Konfirmasi Pembayaran Tunai')),
      body: pendingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
        data: (transactions) {
          if (transactions.isEmpty) {
            return const Center(
              child: AppEmptyState(
                icon: Icons.check_circle_outline,
                title: 'Tidak Ada Menunggu',
                message: 'Tidak ada pembayaran tunai yang perlu dikonfirmasi saat ini.',
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: transactions.length,
            itemBuilder: (context, index) {
              final tx = transactions[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Tunai', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text(formatDateId(tx.createdAt), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Order ID: ${tx.orderId}'),
                      Text('Total: ${formatRupiah(tx.grossAmount)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                              onPressed: _isLoading ? null : () => _confirmPayment(tx, 'failed'),
                              child: const Text('Tolak'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: _isLoading ? null : () => _confirmPayment(tx, 'success'),
                              child: const Text('Terima Uang'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
