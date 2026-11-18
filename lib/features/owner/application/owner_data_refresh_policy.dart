import 'package:supabase_flutter/supabase_flutter.dart';

/// Tables whose newly inserted rows should refresh the owner workspace.
const ownerRefreshTables = <String>[
  'properties',
  'rooms',
  'tenants',
  'payments',
  'payment_transactions',
  'maintenance_reports',
];

/// Owner workspace refresh is deliberately insert-only.
///
/// Updates are handled by the screen that performs them. Listening to UPDATE
/// and DELETE events caused status/category edits to trigger a second reload.
bool shouldRefreshOwnerData({
  required String table,
  required PostgresChangeEvent event,
}) {
  return ownerRefreshTables.contains(table) &&
      event == PostgresChangeEvent.insert;
}
