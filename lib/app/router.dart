import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/auth/role_guard.dart';
import '../domain/models/app_role.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/auth/presentation/registration_page.dart';
import '../features/home/presentation/home_gate_page.dart';
import '../features/settings/presentation/settings_page.dart';

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
      GoRoute(path: '/register', builder: (context, state) => const RegistrationPage()),
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
    ],
    redirect: (context, state) {
      final isAuthenticated =
          Supabase.instance.client.auth.currentSession != null;
      final isPublicAuthRoute =
          state.matchedLocation == '/login' || state.matchedLocation == '/register';

      if (!isAuthenticated && !isPublicAuthRoute) return '/login';
      if (isAuthenticated && isPublicAuthRoute) return '/home';

      // Do not apply profile/role redirects before authentication. In
      // particular, a signed-out user must be allowed to stay on /login and
      // /register; redirecting them to /home here creates /login <-> /home.
      if (isAuthenticated) {
        final profile = ref.read(currentProfileProvider).value;

        // While the profile is loading, let /home render its loading state.
        // Once loaded, HomeGatePage displays a clear notice for tenant users.
        if (profile != null && state.matchedLocation != '/home') {
          final redirectTarget = RoleGuard.resolveRedirect(
            role: profile.role,
            requestedPath: state.matchedLocation,
          );
          if (redirectTarget != null &&
              redirectTarget != state.matchedLocation) {
            return redirectTarget;
          }
        }
      }

      return null;
    },
  );
});
