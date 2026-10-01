import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/settings/presentation/theme_controller.dart';
import 'router.dart';
import 'theme/app_theme.dart';

class KosManageApp extends ConsumerWidget {
  const KosManageApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref
        .watch(themeModeProvider)
        .maybeWhen(data: (mode) => mode, orElse: () => ThemeMode.system);

    return MaterialApp.router(
      title: 'KosManage Mobile',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
