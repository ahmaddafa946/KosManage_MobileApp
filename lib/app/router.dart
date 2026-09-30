import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/auth/presentation/login_page.dart';
import '../features/home/presentation/home_gate_page.dart';
import '../features/settings/presentation/settings_page.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeGatePage(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsPage(),
      ),
    ],
    redirect: (context, state) {
      final isAuthenticated =
          Supabase.instance.client.auth.currentSession != null;
      final isLogin = state.matchedLocation == '/login';

      if (!isAuthenticated && !isLogin) return '/login';
      if (isAuthenticated && isLogin) return '/home';
      return null;
    },
  );
});
