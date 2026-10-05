class AppConfig {
  const AppConfig({required this.supabaseUrl, required this.supabaseAnonKey});

  final String supabaseUrl;
  final String supabaseAnonKey;

  static AppConfig fromEnvironment() {
    return const AppConfig(
      supabaseUrl: String.fromEnvironment('https://aamizrsuxbaaiiafrile.supabase.co'),
      supabaseAnonKey: String.fromEnvironment('sb_publishable_K52HV6sFDZkDlloL6CnZNg_ZeijOW-x'),
    );
  }

  bool get isValid {
    final uri = Uri.tryParse(supabaseUrl);
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host.isNotEmpty &&
        supabaseAnonKey.trim().isNotEmpty;
  }
}
