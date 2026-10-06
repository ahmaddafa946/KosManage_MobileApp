import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'core/config/app_config.dart';
import 'core/bootstrap/app_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeAppLocalization();

  final config = AppConfig.fromEnvironment();
  if (!config.isValid) {
    runApp(const ProviderScope(child: ConfigurationMissingApp()));
    return;
  }

  await Supabase.initialize(
    url: config.supabaseUrl,
    publishableKey: config.supabaseAnonKey,
  );

  runApp(const ProviderScope(child: KosManageApp()));
}

class ConfigurationMissingApp extends StatelessWidget {
  const ConfigurationMissingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KosManage Mobile',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0B6E69)),
        useMaterial3: true,
      ),
      home: const Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Konfigurasi Supabase belum tersedia.\n\n'
                'Jalankan aplikasi dengan SUPABASE_URL dan SUPABASE_ANON_KEY '
                'melalui --dart-define atau --dart-define-from-file.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
