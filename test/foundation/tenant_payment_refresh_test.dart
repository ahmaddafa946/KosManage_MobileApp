import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kos_manage_mobile/data/repositories/payment_transaction_repository.dart';
import 'package:kos_manage_mobile/data/repositories/tenant_repository.dart';
import 'package:kos_manage_mobile/domain/models/owner_management.dart';
import 'package:kos_manage_mobile/domain/models/payment_transaction.dart';
import 'package:kos_manage_mobile/domain/services/payment_transaction_status.dart';
import 'package:kos_manage_mobile/features/tenant/application/tenant_payment_providers.dart';
import 'package:kos_manage_mobile/features/tenant/presentation/tenant_shell_page.dart';

void main() {
  test(
    'payment refresh signal updates cached bill and transaction queries',
    () async {
      final tenant = OwnerTenant(
        id: 'tenant-1',
        name: 'Tenant Test',
        status: 'active',
        startDate: '2026-01-01',
        endDate: '2026-12-31',
        roomId: 'room-1',
        roomNumber: 'A-01',
        rentPrice: 1400000,
        deposit: 500000,
      );
      final myTenant = MyTenant(
        propertyId: 'property-1',
        tenant: tenant,
      );
      final invoice = OwnerPayment(
        id: 'invoice-1',
        billingPeriod: '2026-10',
        dueDate: '2026-10-11',
        amountDue: 1400000,
        amountPaid: 0,
        status: 'unpaid',
      );

      final repo = _FakeTenantRepository(
        myTenant: myTenant,
        payments: [invoice],
      );
      final txRepo = _FakePaymentTransactionRepository(
        transactions: [_transaction(status: 'pending')],
      );

      final container = ProviderContainer(
        overrides: [
          tenantRepositoryProvider.overrideWith((ref) => repo),
          currentTenantProvider.overrideWith((ref) async => myTenant),
          paymentTransactionRepositoryProvider.overrideWith((ref) => txRepo),
        ],
      );
      addTearDown(container.dispose);

      final initialBills = await container.read(
        tenantRecentPaymentsProvider(myTenant).future,
      );
      final initialTransactions = await container.read(
        tenantRecentTransactionsProvider.future,
      );

      expect(initialBills.single.status, 'unpaid');
      expect(initialTransactions.single.status, 'pending');

      repo.payments = [
        OwnerPayment(
          id: invoice.id,
          billingPeriod: invoice.billingPeriod,
          dueDate: invoice.dueDate,
          amountDue: invoice.amountDue,
          amountPaid: invoice.amountDue,
          status: 'paid',
        ),
      ];
      txRepo.transactions = [_transaction(status: 'success')];

      container.read(tenantPaymentDataRefreshProvider.notifier).state++;

      final refreshedBills = await container.read(
        tenantRecentPaymentsProvider(myTenant).future,
      );
      final refreshedTransactions = await container.read(
        tenantRecentTransactionsProvider.future,
      );

      expect(refreshedBills.single.status, 'paid');
      expect(refreshedTransactions.single.status, 'success');
    },
  );
}

PaymentTransaction _transaction({required String status}) {
  return PaymentTransaction(
    id: 'tx-1',
    paymentId: 'invoice-1',
    tenantId: 'tenant-1',
    orderId: 'ORDER-1',
    paymentMethod: 'qris',
    paymentProvider: 'midtrans',
    grossAmount: 1400000,
    status: status,
    expiresAt: '2026-12-31T00:00:00Z',
    createdAt: '2026-10-08T00:00:00Z',
  );
}

class _FakePaymentTransactionRepository
    implements PaymentTransactionRepository {
  _FakePaymentTransactionRepository({required this.transactions});

  List<PaymentTransaction> transactions;

  @override
  Future<void> cancelTransaction(String transactionId) async {}

  @override
  Future<PaymentTransaction?> getActiveTransaction(String paymentId) async {
    for (final transaction in transactions) {
      if (transaction.paymentId == paymentId &&
          isActivePaymentTransactionStatus(transaction.status)) {
        return transaction;
      }
    }
    return null;
  }

  @override
  Future<List<PaymentTransaction>> getMyTransactions(String tenantId) async {
    return transactions;
  }
}

class _FakeTenantRepository implements TenantRepository {
  _FakeTenantRepository({
    required this.myTenant,
    required this.payments,
  });

  final MyTenant myTenant;
  List<OwnerPayment> payments;

  @override
  Future<Map<String, dynamic>> createCashPayment({
    required String invoiceId,
  }) async => {};

  @override
  Future<Map<String, dynamic>> createPaymentIntent({
    required String invoiceId,
    required String paymentMethod,
    String? bank,
  }) async => {};

  @override
  Future<void> createReport({
    required String propertyId,
    required String tenantId,
    required String? roomId,
    required String title,
    required String description,
    required String category,
    required String priority,
    File? photo,
  }) async {}

  @override
  Future<List<OwnerMaintenanceReport>> getMyReports(String tenantId) async {
    return [];
  }

  @override
  Future<List<OwnerPayment>> getMyPayments(
    String propertyId,
    String tenantId,
  ) async {
    return payments;
  }

  @override
  Future<MyTenant> getMyTenant(String profileId) async => myTenant;

  @override
  Future<MyTenant> getMyTenantByEmail(String email) async => myTenant;
}
