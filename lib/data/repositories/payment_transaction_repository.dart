import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/payment_transaction.dart';

abstract interface class PaymentTransactionRepository {
  Future<List<PaymentTransaction>> getMyTransactions(String tenantId);
  Future<PaymentTransaction?> getActiveTransaction(String paymentId);
  Future<void> cancelTransaction(String transactionId);
}

class SupabasePaymentTransactionRepository implements PaymentTransactionRepository {
  SupabasePaymentTransactionRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<PaymentTransaction>> getMyTransactions(String tenantId) async {
    final rows = await _client
        .from('payment_transactions')
        .select('*')
        .eq('tenant_id', tenantId)
        .order('created_at', ascending: false)
        .limit(20);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(PaymentTransaction.fromJson)
        .toList(growable: false);
  }

  @override
  Future<PaymentTransaction?> getActiveTransaction(String paymentId) async {
    final row = await _client
        .from('payment_transactions')
        .select('*')
        .eq('payment_id', paymentId)
        .inFilter('status', ['created', 'pending'])
        .limit(1)
        .maybeSingle();

    if (row == null) return null;
    return PaymentTransaction.fromJson(row);
  }

  @override
  Future<void> cancelTransaction(String transactionId) async {
    // Only cancel if still pending/created
    await _client
        .from('payment_transactions')
        .update({'status': 'cancelled'})
        .eq('id', transactionId)
        .inFilter('status', ['created', 'pending']);
  }
}
