import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/albums/album_detail_screen.dart';
import '../../features/albums/albums_screen.dart';
import '../../features/detail/detail_screen.dart';
import '../../features/detail/photo_viewer_args.dart';
import '../../features/folders/folder_detail_screen.dart';
import '../../features/library/day_grid_screen.dart';
import '../../features/library/library_screen.dart';
import '../../features/library/month_grid_screen.dart';
import '../../features/library/older_grid_screen.dart';
import '../../features/library/year_grid_screen.dart';
import '../../features/memories/memory_player_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/people/people_screen.dart';
import '../../features/people/person_detail_screen.dart';
import '../../features/saved/saved_screen.dart';
import '../../features/search/search_screen.dart';
import '../../features/settings/analysis_settings_screen.dart';
import '../../features/settings/consent_provider.dart';
import '../../features/settings/settings_screen.dart';
import '../../services/permission_provider.dart';
import '../../services/photo_library_service.dart';
import '../../widgets/app_shell.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// App-wide [GoRouter], kept alive for the app's lifetime. Routing structure
/// is documented in docs/spec.md#routing.
///
/// A [redirect] gates the whole app on photo-library access **and** on the
/// on-device analysis consent prompt: without either the user is held on
/// `/onboarding`. It re-runs whenever [permissionProvider] or [consentProvider]
/// changes (via the [ValueNotifier] refresh bridge), so granting access in the
/// onboarding flow, answering the consent step, or revoking access in system
/// settings mid-session all move the user to the right place automatically.
final routerProvider = Provider<GoRouter>((ref) {
  // The value is only a change signal — the redirect reads both providers
  // itself — so consent changes just bump the counter.
  final refresh = ValueNotifier<int>(0);
  ref.listen<PhotoAccess>(permissionProvider, (_, _) => refresh.value++);
  ref.listen<ConsentState>(consentProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final canRead = ref.read(permissionProvider).canReadLibrary;
      final onOnboarding = state.matchedLocation == '/onboarding';
      if (!canRead) return onOnboarding ? null : '/onboarding';
      // Access granted but the consent step is still owed — the onboarding
      // screen shows it. `unresolved` deliberately doesn't redirect (see
      // ConsentNotifier), so an existing user never flashes past it.
      if (ref.read(consentProvider) == ConsentState.needed) {
        return onOnboarding ? null : '/onboarding';
      }
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
        pageBuilder: (context, state) => NoTransitionPage(
          key: state.pageKey,
          child: MonthGridScreen(monthKey: state.pathParameters['key']!),
        ),
      ),
      GoRoute(
        path: '/older',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => NoTransitionPage(
          key: state.pageKey,
          child: const OlderGridScreen(),
        ),
      ),
      GoRoute(
        path: '/year/:year',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => NoTransitionPage(
          key: state.pageKey,
          child: YearGridScreen(yearKey: state.pathParameters['year']!),
        ),
      ),
      GoRoute(
        path: '/day/:date',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => NoTransitionPage(
          key: state.pageKey,
          child: DayGridScreen(dateKey: state.pathParameters['date']!),
        ),
      ),
      GoRoute(
        path: '/settings',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => NoTransitionPage(
          key: state.pageKey,
          child: const SettingsScreen(),
        ),
      ),
      GoRoute(
        path: '/settings/analysis',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => NoTransitionPage(
          key: state.pageKey,
          child: const AnalysisSettingsScreen(),
        ),
      ),
      GoRoute(
        path: '/people',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => NoTransitionPage(
          key: state.pageKey,
          child: const PeopleScreen(),
        ),
      ),
      GoRoute(
        path: '/person/:id',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '');
          return NoTransitionPage(
            key: state.pageKey,
            child: id == null
                ? const _NotFound(message: 'That person couldn\'t be found.')
                : PersonDetailScreen(personId: id),
          );
        },
      ),
      GoRoute(
        path: '/album/:id',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '');
          return NoTransitionPage(
            key: state.pageKey,
            child: id == null
                ? const _InvalidAlbum()
                : AlbumDetailScreen(albumId: id),
          );
        },
      ),
      GoRoute(
        // Query parameters, not a path segment: an iOS folder id is a
        // PHAssetCollection local identifier and may contain `/`, which no
        // amount of encoding makes safe in a `:id` segment. `name` only titles
        // the app bar, so a deep link may omit it.
        path: '/folder',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          final id = state.uri.queryParameters['id'];
          return NoTransitionPage(
            key: state.pageKey,
            child: id == null || id.isEmpty
                ? const _NotFound(message: 'That folder couldn\'t be found.')
                : FolderDetailScreen(
                    folderId: id,
                    folderName: state.uri.queryParameters['name'],
                  ),
          );
        },
      ),
      GoRoute(
        path: '/photo/:id',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => NoTransitionPage(
          key: state.pageKey,
          child: PhotoDetailScreen(
            // `extra` carries the swipe sequence; a deep link / restore (no
            // extra) falls back to a single-asset viewer built from the path id.
            args:
                state.extra as PhotoViewerArgs? ??
                PhotoViewerArgs([state.pathParameters['id']!], 0),
          ),
        ),
      ),
      GoRoute(
        // Full-screen like the detail viewer, so it sits outside the shell —
        // the nav bar would break the story.
        path: '/memory/:id',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => NoTransitionPage(
          key: state.pageKey,
          child: MemoryPlayerScreen(
            memoryId: int.parse(state.pathParameters['id']!),
          ),
        ),
      ),
      StatefulShellRoute(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        // Same indexed-stack layout as the `.indexedStack` constructor: each
        // visited branch keeps its state and scroll position; only the current
        // tab is on stage.
        navigatorContainerBuilder: (context, navigationShell, children) =>
            _BranchContainer(
              navigationShell: navigationShell,
              children: children,
            ),
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
                path: '/search',
                builder: (context, state) => const SearchScreen(),
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
        ],
      ),
    ],
  );
});

/// The shell's branch host: an [IndexedStack] (so every visited branch keeps
/// its state and scroll position) with only the current tab on stage. Mirrors
/// go_router's built-in `.indexedStack` container.
class _BranchContainer extends StatelessWidget {
  const _BranchContainer({
    required this.navigationShell,
    required this.children,
  });

  final StatefulNavigationShell navigationShell;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: navigationShell.currentIndex,
      sizing: StackFit.expand,
      children: children,
    );
  }
}

/// Shown when `/album/:id` carries a non-integer id (a malformed deep link).
class _InvalidAlbum extends StatelessWidget {
  const _InvalidAlbum();

  @override
  Widget build(BuildContext context) {
    return const _NotFound(message: 'That album couldn\'t be found.');
  }
}

/// Generic "not found" fallback for malformed deep links.
class _NotFound extends StatelessWidget {
  const _NotFound({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(child: Text(message)),
    );
  }
}
