/// Demo credentials shown by the login page for each selected role.
///
/// These accounts must exist in Supabase Auth and have a matching public profile.
/// Keep this configuration limited to non-production/demo environments.
class DemoCredentials {
  const DemoCredentials({required this.email, required this.password});

  final String email;
  final String password;
}

DemoCredentials demoCredentialsForRole(String role) {
  switch (role) {
    case 'tenant':
      return const DemoCredentials(
        email: 'tenant.demo@kosmanage.dev',
        password: 'KosManage!dev2',
      );
    case 'owner':
    default:
      return const DemoCredentials(
        email: 'owner@kosmanage.dev',
        password: 'KosManage!dev1',
      );
  }
}
