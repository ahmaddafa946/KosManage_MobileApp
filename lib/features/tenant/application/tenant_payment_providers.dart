import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/repositories/payment_transaction_repository.dart';
import '../../../domain/models/payment_transaction.dart';
import '../presentation/tenant_shell_page.dart';

final paymentTransactionRepositoryProvider = Provider<PaymentTransactionRepository>((ref) {
  return SupabasePaymentTransactionRepository(Supabase.instance.client);
});

final tenantActiveTransactionProvider = FutureProvider.autoDispose.family<PaymentTransaction?, String>((ref, paymentId) async {
  return ref.read(paymentTransactionRepositoryProvider).getActiveTransaction(paymentId);
});

final tenantRecentTransactionsProvider = FutureProvider.autoDispose<List<PaymentTransaction>>((ref) async {
  final tenantAsync = await ref.watch(currentTenantProvider.future);
  if (tenantAsync == null) return [];
  return ref.read(paymentTransactionRepositoryProvider).getMyTransactions(tenantAsync.tenant.id);
});

// Real-time status update provider
final paymentTransactionRealtimeProvider = StreamProvider.family<PaymentTransaction?, String>((ref, transactionId) {
  final client = Supabase.instance.client;
  return client
      .from('payment_transactions')
      .stream(primaryKey: ['id'])
      .eq('id', transactionId)
      .map((event) {
        if (event.isEmpty) return null;
        return PaymentTransaction.fromJson(event.first);
      });
});
