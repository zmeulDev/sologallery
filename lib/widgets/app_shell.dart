import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/search/search_providers.dart';
import 'indexing_dial.dart';
import 'nav_pill_bar.dart';

/// Index of the Search branch in the nav bar / the router's branch list.
const _searchBranchIndex = 1;

/// Root scaffold hosting the four-tab [StatefulNavigationShell] plus the custom
/// bottom navigation bar.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Publish tab activation so the Search field can take focus when its tab is
    // selected and release it when it isn't — the branch outlives the visit, so
    // `autofocus` would neither re-fire on return nor free the keyboard.
    final searchActive = navigationShell.currentIndex == _searchBranchIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      ref.read(searchTabActiveProvider.notifier).set(searchActive);
    });

    return Scaffold(
      // The nav capsule floats over the page. Scrollers in each branch pad
      // their bottom by `MediaQuery.paddingOf(context).bottom`, which the
      // Scaffold sets to the capsule's height for the body.
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: NavPillBar(
        // The indexing dial rides beside the capsule, so it is over every
        // branch — and over anything pushed inside a branch — and no screen
        // silently looks incomplete while analysis is still running. It shows
        // nothing when idle.
        trailing: const IndexingDial(),
        currentIndex: navigationShell.currentIndex,
        onTap: (index) => navigationShell.goBranch(
          index,
          // Re-tapping the active tab pops it to its initial route.
          initialLocation: index == navigationShell.currentIndex,
        ),
      ),
    );
  }
}
