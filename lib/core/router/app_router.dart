import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/albums/albums_screen.dart';
import '../../features/library/library_screen.dart';
import '../../features/library/month_grid_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/saved/saved_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../services/permission_provider.dart';
import '../../services/photo_library_service.dart';
import '../../widgets/app_shell.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// App-wide [GoRouter], kept alive for the app's lifetime. Routing structure
/// is documented in docs/spec.md#routing.
///
/// A [redirect] gates the whole app on photo-library access: without it the
/// user is held on `/onboarding`. It re-runs whenever [permissionProvider]
/// changes (via the [ValueNotifier] refresh bridge), so granting access in the
/// onboarding flow — or revoking it in system settings mid-session — moves the
/// user to the right place automatically.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<PhotoAccess>(ref.read(permissionProvider));
  ref.listen<PhotoAccess>(permissionProvider, (_, next) => refresh.value = next);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final canRead = ref.read(permissionProvider).canReadLibrary;
      final onOnboarding = state.matchedLocation == '/onboarding';
      if (!canRead) return onOnboarding ? null : '/onboarding';
      if (onOnboarding) return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/month/:key',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            MonthGridScreen(monthKey: state.pathParameters['key']!),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const LibraryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/saved',
                builder: (context, state) => const SavedScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/albums',
                builder: (context, state) => const AlbumsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
