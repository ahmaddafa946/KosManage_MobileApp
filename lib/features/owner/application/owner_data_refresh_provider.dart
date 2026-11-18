import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'owner_dashboard_provider.dart';
import 'owner_data_refresh_policy.dart';
import 'owner_module_providers.dart';

/// Refreshes owner screens only after new rows arrive in watched tables.
///
/// There is no timer or app-resume refresh. A short debounce coalesces a batch
/// of related INSERT events into one workspace refresh.
final ownerDataRefreshProvider = StreamProvider.autoDispose<int>((ref) {
  final client = Supabase.instance.client;
  final controller = StreamController<int>();
  final pendingTables = <String>{};
  var revision = 0;
  Timer? debounce;

  void flushPendingRefresh() {
    debounce = null;
    if (controller.isClosed || pendingTables.isEmpty) return;

    final changedTables = Set<String>.of(pendingTables);
    pendingTables.clear();

    // A new property may change which property is considered primary.
    if (changedTables.contains('properties')) {
      ref.invalidate(ownerPropertyProvider);
    }
    ref.invalidate(ownerDashboardProvider);
    ref.invalidate(ownerPendingCashTransactionsProvider);
    controller.add(++revision);
  }

  void queueRefresh(String table) {
    if (controller.isClosed) return;
    pendingTables.add(table);
    debounce?.cancel();
    debounce = Timer(
      const Duration(milliseconds: 350),
      flushPendingRefresh,
    );
  }

  var channel = client.channel('kosmanage-owner-insert-refresh');
  for (final table in ownerRefreshTables) {
    if (!shouldRefreshOwnerData(
      table: table,
      event: PostgresChangeEvent.insert,
    )) {
      continue;
    }

    channel = channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: table,
      callback: (_) => queueRefresh(table),
    );
  }

  channel.subscribe();
  controller.add(0);

  ref.onDispose(() {
    debounce?.cancel();
    pendingTables.clear();
    unawaited(client.removeChannel(channel));
    unawaited(controller.close());
  });

  return controller.stream;
});
