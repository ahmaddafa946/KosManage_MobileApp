import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'theme_controller.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeModeProvider);
    final currentMode = themeState.value ?? ThemeMode.system;

    Future<void> setTheme(ThemeMode? mode) async {
      if (mode != null) {
        await ref.read(themeModeProvider.notifier).setThemeMode(mode);
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Tampilan',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          Card(
            child: RadioGroup<ThemeMode>(
              groupValue: currentMode,
              onChanged: setTheme,
              child: const Column(
                children: [
                  RadioListTile<ThemeMode>(
                    value: ThemeMode.system,
                    title: Text('Ikuti sistem'),
                    subtitle: Text('Mengikuti mode terang/gelap perangkat.'),
                  ),
                  RadioListTile<ThemeMode>(
                    value: ThemeMode.light,
                    title: Text('Mode terang'),
                  ),
                  RadioListTile<ThemeMode>(
                    value: ThemeMode.dark,
                    title: Text('Mode gelap'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Text(
                'Keamanan: aplikasi mobile hanya memakai Supabase publishable/anon key. '
                'Service-role/secret key tidak boleh disimpan di client.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
