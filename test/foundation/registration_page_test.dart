import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kos_manage_mobile/features/auth/presentation/registration_page.dart';

void main() {
  testWidgets('registration page collects owner name, email and password', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: RegistrationPage()),
      ),
    );

    expect(find.byKey(const Key('register-name')), findsOneWidget);
    expect(find.byKey(const Key('register-email')), findsOneWidget);
    expect(find.byKey(const Key('register-password')), findsOneWidget);
    expect(find.byKey(const Key('register-confirm-password')), findsOneWidget);
    expect(find.byKey(const Key('register-submit')), findsOneWidget);
    expect(find.textContaining('pemilik'), findsWidgets);
  });
}
