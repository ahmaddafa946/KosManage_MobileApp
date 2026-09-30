import 'package:flutter_test/flutter_test.dart';
import 'package:kos_manage_mobile/core/config/app_config.dart';

void main() {
  test('accepts a valid public Supabase configuration', () {
    final config = AppConfig(
      supabaseUrl: 'https://example.supabase.co',
      supabaseAnonKey: 'public-anon-key',
    );

    expect(config.isValid, isTrue);
  });

  test('rejects a non-https Supabase URL', () {
    final config = AppConfig(
      supabaseUrl: 'http://example.supabase.co',
      supabaseAnonKey: 'public-anon-key',
    );

    expect(config.isValid, isFalse);
  });
}
