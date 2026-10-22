import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'owner_dashboard_provider.dart';
import 'owner_module_providers.dart';

/// Keeps owner screens fresh when the app resumes, relevant database rows
/// change through Realtime, or the fallback polling interval elapses.
final ownerDataRefreshProvider = StreamProvider.autoDispose<int>((ref) {
  final client = Supabase.instance.client;
  final controller = StreamController<int>();
  var revision = 0;

  void refresh() {
    if (controller.isClosed) return;
    revision++;
    ref.invalidate(ownerPropertyProvider);
    ref.invalidate(ownerDashboardProvider);
    ref.invalidate(ownerPendingCashTransactionsProvider);
    controller.add(revision);
  }

  final timer = Timer.periodic(const Duration(seconds: 30), (_) => refresh());
  final lifecycleObserver = _OwnerRefreshLifecycleObserver(refresh);
  WidgetsBinding.instance.addObserver(lifecycleObserver);

  var channel = client.channel('kosmanage-owner-auto-refresh');
  for (final table in const [
    'properties',
    'rooms',
    'tenants',
    'payments',
    'payment_transactions',
    'maintenance_reports',
  ]) {
    channel = channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: table,
      callback: (_) => refresh(),
    );
  }
  channel.subscribe();
  controller.add(0);

  ref.onDispose(() {
    timer.cancel();
    WidgetsBinding.instance.removeObserver(lifecycleObserver);
    unawaited(client.removeChannel(channel));
    unawaited(controller.close());
  });

  return controller.stream;
});

class _OwnerRefreshLifecycleObserver with WidgetsBindingObserver {
  _OwnerRefreshLifecycleObserver(this.onResume);

  final VoidCallback onResume;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) onResume();
  }
}
