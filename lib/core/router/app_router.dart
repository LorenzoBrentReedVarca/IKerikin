import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/providers.dart';
import '../../domain/models.dart';
import '../../presentation/screens/auth_screens.dart';
import '../../presentation/screens/child_screens.dart';
import '../../presentation/screens/learning_screens.dart';
import '../../presentation/screens/support_screens.dart';
import '../../presentation/widgets/app_shell.dart';

/// Converts a stream into a GoRouter refresh signal.
class RouterRefreshNotifier extends ChangeNotifier {
  RouterRefreshNotifier(Stream<Object?> stream) {
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }
  late final StreamSubscription<Object?> _subscription;
  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

/// Provides declarative, session-aware application routing.
final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authRepositoryProvider);
  final refresh = RouterRefreshNotifier(auth.watchUser());
  ref.onDispose(refresh.dispose);
  return GoRouter(
    initialLocation: '/home',
    refreshListenable: refresh,
    redirect: (context, state) {
      final session = ref.read(authStateProvider);
      if (session.isLoading) return null;
      final signedIn = session.value != null;
      final public =
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/register' ||
          state.matchedLocation == '/forgot-password' ||
          state.matchedLocation == '/verify-email';
      if (!signedIn && !public) return '/login';
      if (signedIn &&
          (state.matchedLocation == '/login' ||
              state.matchedLocation == '/register'))
        return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
      GoRoute(
        path: '/forgot-password',
        builder: (_, _) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/verify-email',
        builder: (_, state) =>
            VerifyEmailScreen(email: state.extra as String? ?? 'your email'),
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => AppShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/learn', builder: (_, _) => const LearnScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/create',
                builder: (_, _) => const LessonGeneratorScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/progress',
                builder: (_, _) => const ProgressScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (_, _) => const ChildProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(path: '/children', builder: (_, _) => const ChildrenScreen()),
      GoRoute(
        path: '/children/new',
        builder: (_, _) => const ChildFormScreen(),
      ),
      GoRoute(
        path: '/children/:id/edit',
        builder: (_, state) =>
            ChildFormScreen(child: state.extra as ChildProfile),
      ),
      GoRoute(
        path: '/lesson/:id',
        builder: (_, state) => LessonRouteScreen(
          lessonId: state.pathParameters['id']!,
          initialLesson: state.extra as Lesson?,
        ),
      ),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
      GoRoute(path: '/admin', builder: (_, _) => const AdminScreen()),
    ],
  );
});
