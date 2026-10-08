import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/repositories/payment_transaction_repository.dart';
import '../../../domain/models/payment_transaction.dart';
import '../../../domain/services/payment_transaction_status.dart';
import '../presentation/tenant_shell_page.dart';

final paymentTransactionRepositoryProvider =
    Provider<PaymentTransactionRepository>((ref) {
  return SupabasePaymentTransactionRepository(Supabase.instance.client);
});

final tenantActiveTransactionProvider =
    FutureProvider.autoDispose.family<PaymentTransaction?, String>((
  ref,
  paymentId,
) async {
  return ref
      .read(paymentTransactionRepositoryProvider)
      .getActiveTransaction(paymentId);
});

final tenantRecentTransactionsProvider =
    FutureProvider.autoDispose<List<PaymentTransaction>>((ref) async {
  final tenantAsync = await ref.watch(currentTenantProvider.future);
  if (tenantAsync == null) return [];
  return ref
      .read(paymentTransactionRepositoryProvider)
      .getMyTransactions(tenantAsync.tenant.id);
});

/// Polls the transaction row instead of relying on Postgres Changes.
///
/// The payment-status Edge Function is called while the transaction is
/// gateway-owned (created/pending) so a delayed/missing Realtime event
/// cannot leave the tenant stuck on a stale payment screen.
final paymentTransactionRealtimeProvider =
    StreamProvider.family<PaymentTransaction?, String>((ref, transactionId) async* {
  final client = Supabase.instance.client;

  while (true) {
    final row = await client
        .from('payment_transactions')
        .select('*')
        .eq('id', transactionId)
        .maybeSingle();

    if (row == null) {
      yield null;
      return;
    }

    var tx = PaymentTransaction.fromJson(row);

    if (shouldSyncPaymentGatewayStatus(tx.status)) {
      try {
        await client.functions.invoke(
          'payment-status',
          body: {'order_id': tx.orderId},
        );
      } catch (_) {
        // Keep rendering the last known transaction state. The next poll
        // will retry the gateway sync.
      }

      final refreshed = await client
          .from('payment_transactions')
          .select('*')
          .eq('id', transactionId)
          .maybeSingle();

      if (refreshed != null) {
        tx = PaymentTransaction.fromJson(refreshed);
      }
    }

    yield tx;

    if (isTerminalPaymentTransactionStatus(tx.status) || tx.isExpired) {
      return;
    }

    await Future<void>.delayed(const Duration(seconds: 3));
  }
});
