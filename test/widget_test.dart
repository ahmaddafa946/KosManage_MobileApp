import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kos_manage_mobile/main.dart';

void main() {
  testWidgets('ConfigurationMissingApp explains missing Supabase configuration',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ConfigurationMissingApp());

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.textContaining('Konfigurasi Supabase belum tersedia'), findsOneWidget);
    expect(find.textContaining('SUPABASE_URL dan SUPABASE_ANON_KEY'), findsOneWidget);
  });
}
