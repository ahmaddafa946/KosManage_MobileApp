import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/auth/role_guard.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/home/presentation/home_gate_page.dart';
import '../features/settings/presentation/settings_page.dart';
import '../features/tenant/presentation/payment_flow.dart';

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.asBroadcastStream().listen(
      (dynamic _) => notifyListeners(),
    );
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refreshListenable = GoRouterRefreshStream(
    Supabase.instance.client.auth.onAuthStateChange,
  );
  ref.onDispose(refreshListenable.dispose);

  return GoRouter(
    initialLocation: '/home',
    refreshListenable: refreshListenable,
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(path: '/home', builder: (context, state) => const HomeGatePage()),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsPage(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const SettingsPage(),
      ),
      // Explicit owner prefixes: blocked at route level, not just hidden UI.
      GoRoute(
        path: '/owner/:section',
        redirect: (context, state) {
          final profile = ref.read(currentProfileProvider).value;
          if (profile == null) return '/home';
          return RoleGuard.resolveRedirect(
            role: profile.role,
            requestedPath: '/owner/${state.pathParameters['section']}',
          );
        },
        builder: (context, state) => const HomeGatePage(),
      ),
      GoRoute(
        path: '/payment/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return ActiveTransactionScreen(transactionId: id);
        },
      ),
    ],
    redirect: (context, state) {
      final isAuthenticated =
          Supabase.instance.client.auth.currentSession != null;
      final isLogin = state.matchedLocation == '/login';

      if (!isAuthenticated && !isLogin) return '/login';
      if (isAuthenticated && isLogin) return '/home';

      // ponytail: role-aware redirect guard for any deep linked owner prefix.
      final profile = ref.read(currentProfileProvider).value;
      if (profile != null) {
        final redirectTarget = RoleGuard.resolveRedirect(
          role: profile.role,
          requestedPath: state.matchedLocation,
        );
        if (redirectTarget != null && redirectTarget != state.matchedLocation) {
          return redirectTarget;
        }
      }

      return null;
    },
  );
});
