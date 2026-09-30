import 'package:flutter_test/flutter_test.dart';
import 'package:kos_manage_mobile/domain/models/user_profile.dart';

void main() {
  test('parses Supabase profile payload using full_name column', () {
    final profile = UserProfile.fromJson({
      'id': '1190ea65-6362-4d8b-a214-80603d9fe57f',
      'full_name': 'owner',
      'role': 'owner',
      'email': 'owner@kosmanage.dev',
    });

    expect(profile.id, '1190ea65-6362-4d8b-a214-80603d9fe57f');
    expect(profile.name, 'owner');
    expect(profile.email, 'owner@kosmanage.dev');
    expect(profile.role.name, 'owner');
  });
}
