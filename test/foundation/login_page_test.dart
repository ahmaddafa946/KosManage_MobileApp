import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kos_manage_mobile/features/auth/presentation/login_page.dart';

void main() {
  testWidgets('login page is owner-only and exposes registration', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: LoginPage())),
      ),
    );

    expect(find.byKey(const Key('login-email')), findsOneWidget);
    expect(find.byKey(const Key('login-password')), findsOneWidget);
    expect(find.byKey(const Key('login-submit')), findsOneWidget);
    expect(find.byKey(const Key('login-register')), findsOneWidget);
    expect(find.text('Penghuni'), findsNothing);
    expect(find.byKey(const Key('login-demo')), findsNothing);
  });
}
