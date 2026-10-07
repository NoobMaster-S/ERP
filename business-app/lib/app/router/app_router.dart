import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/authentication/presentation/bloc/auth_bloc.dart';
import '../../features/authentication/presentation/pages/login_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../core/sync/sync_engine.dart';

class GoRouterRefreshStream extends ChangeNotifier {
  late final StreamSubscription<dynamic> _subscription;

  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription =
        stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

GoRouter createRouter({
  required AuthBloc authBloc,
  required SyncEngine syncEngine,
}) {
  return GoRouter(
    initialLocation: authBloc.state is AuthAuthenticated ? '/' : '/login',
    refreshListenable: GoRouterRefreshStream(authBloc.stream),
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => DashboardPage(syncEngine: syncEngine),
      ),
    ],
    redirect: (BuildContext context, GoRouterState state) {
      final authState = authBloc.state;
      final isLoggingIn = state.matchedLocation == '/login';

      // If user is authenticated, keep them on dashboard
      if (authState is AuthAuthenticated) {
        return isLoggingIn ? '/' : null;
      }

      // If user is explicitly unauthenticated, redirect to login
      if (authState is AuthUnauthenticated) {
        return isLoggingIn ? null : '/login';
      }

      // In initial or loading states, do not prematurely kick user out
      return null;
    },
  );
}
