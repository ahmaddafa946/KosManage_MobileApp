import 'app_role.dart';

class UserProfile {
  const UserProfile({
    required this.id,
    required this.name,
    required this.role,
    this.email,
  });

  final String id;
  final String name;
  final AppRole role;
  final String? email;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String?;
    final name = json['name'] as String?;
    final role = json['role'] as String?;

    if (id == null || name == null || role == null) {
      throw const FormatException('Profile payload tidak lengkap.');
    }

    return UserProfile(
      id: id,
      name: name,
      role: AppRole.fromDatabase(role),
      email: json['email'] as String?,
    );
  }
}
