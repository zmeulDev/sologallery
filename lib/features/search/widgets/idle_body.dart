import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_space.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../widgets/people_strip.dart';
import '../../people/people_providers.dart';
import '../../settings/consent_provider.dart' show searchEnabledProvider;
import '../search_providers.dart';
import 'browse_labels.dart';
import 'recently_viewed_row.dart';

/// The idle state: facet pills at the top, then browse entry points (labels,
/// people), then the search field and subtitle, and the recency carousel at the
/// bottom. Device folders deliberately live on the Albums tab and not here:
/// they are a place you browse *collections*, not a way to narrow a query.
class IdleBody extends ConsumerWidget {
  const IdleBody({
    super.key,
    required this.searchField,
    required this.filterBar,
    required this.onBrowseLabel,
  });

  /// The shared search field, placed below the browse entry points.
  final Widget searchField;

  /// The shared facet bar, visible before a query is entered and placed at the
  /// top of the screen.
  final Widget filterBar;

  /// Commits a tapped label chip as the active query.
  final void Function(String) onBrowseLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final people = ref.watch(personSummariesProvider).value ?? const [];
    final searchOn = ref.watch(searchEnabledProvider).value ?? false;
    // Only what the library actually carries: with content search off there is
    // nothing to browse, and while the indexer is still working the list fills
    // in as labels land.
    final labels = searchOn
        ? ref.watch(topBrowseLabelsProvider).value ?? const <String>[]
        : const <String>[];

    return ListView(
      // Clears the floating nav capsule (reported as the bottom inset).
      padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
      children: [
        filterBar,
        const _SearchSubtitle(),
        searchField,
        if (labels.isNotEmpty)
          BrowseLabels(labels: labels, onTap: onBrowseLabel),
        if (people.isNotEmpty) PeopleStrip(people: people),
        const _RecentlyViewedStrip(),
        if (people.isEmpty && labels.isEmpty) const _IdleHint(),
      ],
    );
  }
}

/// Compact subtitle for the idle Search screen, replacing the previous large
/// page title so the search field can stay anchored at the top.
class _SearchSubtitle extends StatelessWidget {
  const _SearchSubtitle();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final styles = Theme.of(context).extension<AppTextStyles>()!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s16,
        AppSpace.s16,
        AppSpace.s16,
        AppSpace.s4,
      ),
      child: Text(
        'Find photos, dates, albums, and more',
        style: styles.body.copyWith(color: colors.textSecondary),
      ),
    );
  }
}

/// The recently viewed ribbon: watches the DAO stream and delegates to the
/// public [RecentlyViewedRow] widget. Loading/error states are silent.
class _RecentlyViewedStrip extends ConsumerWidget {
  const _RecentlyViewedStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = ref.watch(recentlyViewedProvider(20));
    return recent.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (ids) => RecentlyViewedRow(assetIds: ids),
    );
  }
}

/// The starting prompt, shown before any query or facet is set.
class _IdleHint extends ConsumerWidget {
  const _IdleHint();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final styles = Theme.of(context).extension<AppTextStyles>()!;
    final searchOn = ref.watch(searchEnabledProvider).value ?? false;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Text(
          searchOn
              ? 'Search your library by what is in a photo, text it contains, '
                    'date, album name, or media type.'
              : 'Search your library by date, album name, or media type. '
                    'Turn on content search in Settings to search by what is in '
                    'a photo.',
          textAlign: TextAlign.center,
          style: styles.body.copyWith(color: colors.textSecondary),
        ),
      ),
    );
  }
}
