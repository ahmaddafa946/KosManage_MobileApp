/// Returns a user-facing message when an account is not allowed to use the
/// owner-only mobile application.
String? ownerOnlyLoginMessage({required String actualRole}) {
  if (actualRole == 'owner') return null;
  return 'Aplikasi KosManage Mobile hanya untuk pemilik kos.';
}
