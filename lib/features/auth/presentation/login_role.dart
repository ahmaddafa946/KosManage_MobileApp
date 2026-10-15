/// Returns a user-facing message when the selected login role does not
/// match the role assigned to the account in the application's profile.
String? roleMismatchMessage({
  required String selectedRole,
  required String actualRole,
}) {
  if (selectedRole == actualRole) return null;

  final actualRoleLabel = actualRole == 'tenant' ? 'penghuni' : 'pemilik kos';
  return 'Akun ini terdaftar sebagai $actualRoleLabel. '
      'Pilih tab yang sesuai, lalu coba lagi.';
}
