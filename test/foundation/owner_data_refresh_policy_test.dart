import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:kos_manage_mobile/features/owner/application/owner_data_refresh_policy.dart';

void main() {
  group('owner data refresh policy', () {
    test('refreshes when a new row is inserted into an owner data table', () {
      for (final table in ownerRefreshTables) {
        expect(
          shouldRefreshOwnerData(table: table, event: PostgresChangeEvent.insert),
          isTrue,
          reason: '$table inserts should refresh owner data',
        );
      }
    });

    test('does not refresh for updates or deletes', () {
      for (final table in ownerRefreshTables) {
        expect(
          shouldRefreshOwnerData(table: table, event: PostgresChangeEvent.update),
          isFalse,
          reason: '$table updates should not trigger background refresh',
        );
        expect(
          shouldRefreshOwnerData(table: table, event: PostgresChangeEvent.delete),
          isFalse,
          reason: '$table deletes should not trigger background refresh',
        );
      }
    });

    test('ignores tables outside the owner refresh scope', () {
      expect(
        shouldRefreshOwnerData(
          table: 'audit_logs',
          event: PostgresChangeEvent.insert,
        ),
        isFalse,
      );
    });
  });
}
