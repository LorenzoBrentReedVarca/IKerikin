import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/providers.dart';
import '../../domain/models.dart';
import '../../presentation/screens/auth_screens.dart';
import '../../presentation/screens/child_screens.dart';
import '../../presentation/screens/dictionary_screen.dart';
import '../../presentation/screens/learning_screens.dart';
import '../../presentation/screens/support_screens.dart';
import '../../presentation/screens/tutorial_screen.dart';
import '../../presentation/widgets/app_shell.dart';

/// Provides declarative, session-aware application routing.
final routerProvider = Provider<GoRouter>((ref) {
  // Ties GoRouter's refresh signal directly to [authStateProvider] — the
  // same provider `redirect` reads below — instead of a second, independent
  // subscription to the auth stream. Two separate subscriptions raced: the
  // standalone one could resolve and notify before GoRouter had finished
  // attaching as a listener, silently dropping the one signal that mattered
  // and leaving a signed-out user stuck on the initial route forever.
  final refresh = ValueNotifier(0);
  ref.listen<AsyncValue<AppUser?>>(
    authStateProvider,
    (_, _) => refresh.value++,
  );
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
      // First-run onboarding: send any signed-in account that hasn't seen
      // the tutorial yet on this device there before anywhere else, no
      // matter how they arrived (fresh registration, email-verification
      // return, or a plain sign-in). It stops firing once the tutorial
      // screen marks the flag seen.
      if (signedIn && state.matchedLocation != '/tutorial') {
        final uid = session.value!.id;
        final seen = ref
            .read(sharedPreferencesProvider)
            .getBool('has_seen_tutorial_$uid');
        if (seen != true) return '/tutorial';
      }
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
        path: '/children/new/preparing',
        builder: (_, state) =>
            PreparingLessonsScreen(child: state.extra as ChildProfile),
      ),
      GoRoute(
        path: '/lesson/:id',
        builder: (_, state) => LessonRouteScreen(
          lessonId: state.pathParameters['id']!,
          initialLesson: state.extra as Lesson?,
        ),
      ),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
      GoRoute(path: '/tutorial', builder: (_, _) => const TutorialScreen()),
      GoRoute(path: '/admin', builder: (_, _) => const AdminScreen()),
      GoRoute(
        path: '/dictionary',
        builder: (_, _) => const WordExplorerScreen(),
      ),
    ],
  );
});
