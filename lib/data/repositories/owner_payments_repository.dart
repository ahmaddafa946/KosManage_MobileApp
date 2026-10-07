import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/owner_management.dart';
import '../../domain/models/payment_transaction.dart';

abstract interface class OwnerPaymentsRepository {
  Future<List<OwnerPayment>> getPayments(
    String propertyId, {
    String billingPeriod = '',
    String status = 'all',
    String method = 'all',
    String? tenantId,
  });

  Future<OwnerPayment> createPayment(
    String propertyId, {
    required String tenantId,
    required String billingPeriod,
    required String dueDate,
    required num amountDue,
    required num amountPaid,
    required String? paymentDate,
    required String? paymentMethod,
    required String notes,
  });

  Future<OwnerPayment> updatePayment(
    String paymentId, {
    required String tenantId,
    required String billingPeriod,
    required String dueDate,
    required num amountDue,
    required num amountPaid,
    required String? paymentDate,
    required String? paymentMethod,
    required String notes,
  });

  Future<void> deletePayment(String paymentId);

  Future<List<PaymentTransaction>> getPendingCashTransactions(String propertyId);
  Future<void> confirmCashPayment(String transactionId, String status);
}

class SupabaseOwnerPaymentsRepository implements OwnerPaymentsRepository {
  SupabaseOwnerPaymentsRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<OwnerPayment>> getPayments(
    String propertyId, {
    String billingPeriod = '',
    String status = 'all',
    String method = 'all',
    String? tenantId,
  }) async {
    var request = _client
        .from('payments')
        .select(
          '*, tenant:tenants!payments_tenant_id_fkey(id,name), '
          'room:rooms!payments_room_id_fkey(id,room_number)',
        )
        .eq('property_id', propertyId);

    if (billingPeriod.isNotEmpty) {
      request = request.eq('billing_period', billingPeriod);
    }
    if (status != 'all') request = request.eq('status', status);
    if (method != 'all') {
      request = request.eq('payment_method', method);
    }
    if (tenantId != null) {
      request = request.eq('tenant_id', tenantId);
    }

    final rows = await request.order('due_date', ascending: false);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(OwnerPayment.fromJson)
        .toList(growable: false);
  }

  Future<OwnerPayment> _reloadPayment(String paymentId) async {
    final row = await _client
        .from('payments')
        .select(
          '*, tenant:tenants!payments_tenant_id_fkey(id,name), '
          'room:rooms!payments_room_id_fkey(id,room_number)',
        )
        .eq('id', paymentId)
        .single();
    return OwnerPayment.fromJson(row);
  }

  @override
  Future<OwnerPayment> createPayment(
    String propertyId, {
    required String tenantId,
    required String billingPeriod,
    required String dueDate,
    required num amountDue,
    required num amountPaid,
    required String? paymentDate,
    required String? paymentMethod,
    required String notes,
  }) async {
    final row = await _client
        .from('payments')
        .insert({
          'property_id': propertyId,
          'tenant_id': tenantId,
          'billing_period': billingPeriod,
          'due_date': dueDate,
          'amount_due': amountDue,
          'amount_paid': amountPaid,
          'payment_date': paymentDate?.isEmpty == true ? null : paymentDate,
          'payment_method': paymentMethod,
          'notes': notes.trim().isEmpty ? null : notes.trim(),
        })
        .select()
        .single();

    return _reloadPayment(row['id'] as String);
  }

  @override
  Future<OwnerPayment> updatePayment(
    String paymentId, {
    required String tenantId,
    required String billingPeriod,
    required String dueDate,
    required num amountDue,
    required num amountPaid,
    required String? paymentDate,
    required String? paymentMethod,
    required String notes,
  }) async {
    await _client
        .from('payments')
        .update({
          'tenant_id': tenantId,
          'billing_period': billingPeriod,
          'due_date': dueDate,
          'amount_due': amountDue,
          'amount_paid': amountPaid,
          'payment_date': paymentDate?.isEmpty == true ? null : paymentDate,
          'payment_method': paymentMethod,
          'notes': notes.trim().isEmpty ? null : notes.trim(),
        })
        .eq('id', paymentId)
        .select()
        .single();

    return _reloadPayment(paymentId);
  }

  @override
  Future<void> deletePayment(String paymentId) async {
    await _client.from('payments').delete().eq('id', paymentId);
  }

  @override
  Future<List<PaymentTransaction>> getPendingCashTransactions(String propertyId) async {
    final rows = await _client
        .from('payment_transactions')
        .select('*, tenant:tenants!payment_transactions_tenant_id_fkey(property_id)')
        .eq('payment_method', 'cash')
        .eq('status', 'pending')
        .eq('tenant.property_id', propertyId)
        .order('created_at', ascending: false);

    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(PaymentTransaction.fromJson)
        .toList(growable: false);
  }

  @override
  Future<void> confirmCashPayment(String transactionId, String status) async {
    final response = await _client.functions.invoke(
      'cash-payment-confirm',
      body: {
        'transaction_id': transactionId,
        'status': status,
      },
    );
  }
}
