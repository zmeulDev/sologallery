import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/daos/albums_dao.dart' show AlbumSummary;
import '../../../core/database/daos/faces_dao.dart' show PersonSummary;
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../widgets/asset_grid.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/people_strip.dart';
import '../../../widgets/section_header.dart';
import '../search_providers.dart';
import 'albums_result.dart';

/// The results body: facets at the top, matching people, then the anchored
/// field + album chips + photo grid. Recently viewed is deliberately absent —
/// once a query is running the screen shows only what matched it.
class ResultsBody extends StatelessWidget {
  const ResultsBody({
    super.key,
    required this.searchField,
    required this.filterBar,
    required this.albums,
    required this.people,
  });

  final Widget searchField;
  final Widget filterBar;
  final List<AlbumSummary> albums;
  final List<PersonSummary> people;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        filterBar,
        if (people.isNotEmpty) PeopleStrip(people: people),
        searchField,
        if (albums.isNotEmpty) AlbumsResult(albums: albums),
        Expanded(
          child: _Results(anyMatch: albums.isNotEmpty || people.isNotEmpty),
        ),
      ],
    );
  }
}

/// Photo results below albums and people. When only non-photo result types
/// matched, the grid area stays empty rather than redundantly claiming "No
/// matches."
class _Results extends ConsumerWidget {
  const _Results({required this.anyMatch});

  final bool anyMatch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assets = ref.watch(searchAssetsProvider);
    return assets.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) =>
          const EmptyState.note('Couldn\'t run that search.'),
      data: (items) {
        if (items.isEmpty) {
          // Albums or people may still be the answer; only claim "no matches"
          // when nothing at all matched.
          return anyMatch
              ? const SizedBox.shrink()
              : const EmptyState.note('No matches.');
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: SectionHeader(
                label: 'Photos',
                trailing: _ResultCount(
                  count: items.length,
                  hasMore: ref
                      .watch(searchAssetsProvider.notifier)
                      .hasMore,
                ),
              ),
            ),
            Expanded(
              child: AssetGrid(
                items: items,
                hasMore: ref.watch(searchAssetsProvider.notifier).hasMore,
                onLoadMore: () =>
                    ref.read(searchAssetsProvider.notifier).loadMore(),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The trailing "N results" tally on the Photos header. A trailing `+` marks a
/// count still growing as more pages load, rather than claiming a total.
class _ResultCount extends StatelessWidget {
  const _ResultCount({required this.count, required this.hasMore});

  final int count;
  final bool hasMore;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final styles = Theme.of(context).extension<AppTextStyles>()!;
    final n = '$count${hasMore ? '+' : ''}';
    return Text(
      count == 1 && !hasMore ? '1 result' : '$n results',
      style: styles.caption.copyWith(color: colors.textSecondary),
    );
  }
}
