import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_space.dart';
import '../../../services/indexing_service.dart';
import '../../../widgets/asset_grid.dart' show kPhotoGridCacheExtent;
import '../../../widgets/empty_state.dart';
import '../../memories/widgets/memories_carousel.dart';
import '../domain/library_filter.dart';
import '../domain/library_timeline.dart';
import '../domain/year_month.dart';
import '../library_providers.dart';
import 'library_filter_bar.dart';
import 'library_bottom_padding.dart';
import 'library_section.dart';
import 'library_skeleton.dart';
import 'month_header.dart';
import 'preview_grid.dart';
import 'refreshable_body.dart';
import 'year_header.dart';

/// The month-grouped timeline, shown by both [LibraryFilter.all] and
/// [LibraryFilter.months] — they share every query and differ only in whether
/// years are announced and the memories carousel rides on top.
class MonthTimeline extends ConsumerWidget {
  const MonthTimeline({super.key, required this.filter});

  final LibraryFilter filter;

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(libraryMonthCountsProvider);
    ref.invalidate(olderCountProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final months = ref.watch(libraryMonthCountsProvider);
    final olderCount = ref.watch(olderCountProvider).value ?? 0;
    // Until the first metadata sweep runs, an empty cache is "not loaded yet",
    // not "no photos" — hold the spinner instead of flashing the empty state.
    final cacheReady = ref.watch(libraryCacheReadyProvider).value ?? false;

    return months.when(
      loading: () => const LibrarySkeleton(),
      error: (e, st) => RefreshableBody(
        onRefresh: () => _refresh(ref),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: libraryBottomPadding(context),
          children: const [
            LibraryFilterBar(),
            EmptyState(
              title: 'Couldn\'t load your photos',
              detail:
                  'Something went wrong reading your library. Pull to try '
                  'again.',
            ),
          ],
        ),
      ),
      data: (counts) {
        if (counts.isEmpty && olderCount == 0) {
          return cacheReady
              ? RefreshableBody(
                  onRefresh: () => _refresh(ref),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: libraryBottomPadding(context),
                    children: const [
                      LibraryFilterBar(),
                      EmptyState(
                        title: 'No photos yet',
                        detail:
                            'Photos you take will appear here, grouped by '
                            'month.',
                      ),
                    ],
                  ),
                )
              : const LibrarySkeleton();
        }
        return RefreshableBody(
          onRefresh: () => _refresh(ref),
          child: _MonthList(
            counts: counts,
            olderCount: olderCount,
            filter: filter,
          ),
        );
      },
    );
  }
}

class _MonthList extends StatelessWidget {
  const _MonthList({
    required this.counts,
    required this.olderCount,
    required this.filter,
  });

  final List<MonthCount> counts;
  final int olderCount;
  final LibraryFilter filter;

  @override
  Widget build(BuildContext context) {
    final rows = buildTimelineRows(
      counts: counts,
      olderCount: olderCount,
      filter: filter,
    );
    return ListView.builder(
      scrollCacheExtent: kPhotoGridCacheExtent,
      // The nav capsule floats over the body, so the Scaffold reports its
      // height as the bottom inset — the last row has to clear it.
      padding: libraryBottomPadding(context),
      itemCount: rows.length,
      itemBuilder: (context, i) {
        final row = rows[i];
        final child = switch (row) {
          MemoriesRow() => const MemoriesCarousel(),
          FilterBarRow() => const LibraryFilterBar(),
          YearRow(:final year, :final count) => YearHeader(
              year: year,
              count: count,
              onTap: () => context.push('/year/$year'),
            ),
          MonthRow(:final month, :final count) => _MonthSection(
              month: month,
              count: count,
            ),
          OlderRow(:final count) => _OlderSection(count: count),
        };
        // Each section is self-contained and fairly heavy (thumbnail grid).
        // Contain repaints so a decode completion in one month does not redraw
        // its neighbours.
        return RepaintBoundary(child: child);
      },
    );
  }
}

/// One calendar-month section; its previews load lazily from the cache as the
/// section scrolls into view.
class _MonthSection extends ConsumerWidget {
  const _MonthSection({required this.month, required this.count});

  final YearMonth month;
  final int count;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final previews = ref.watch(monthPreviewsProvider(month)).value;
    return Padding(
      // The whole gap between two sections lives on the top edge. Splitting it
      // across a top *and* a bottom pad makes the visible gap their sum, which
      // is how it drifted to 36px and read as a break rather than a rhythm.
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s8,
        AppSpace.s20,
        AppSpace.s8,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            // The header keeps the standard screen inset; only the grid below
            // runs wider, so the label still lines up with every other screen's
            // left edge.
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.s8),
            child: MonthHeader(
              month: month,
              count: count,
              onTap: () => context.push('/month/${month.key}'),
            ),
          ),
          const SizedBox(height: 10),
          PreviewGrid(assetIds: previews ?? const []),
        ],
      ),
    );
  }
}

/// The trailing "Older" section (undated photos), previews loaded lazily.
class _OlderSection extends ConsumerWidget {
  const _OlderSection({required this.count});

  final int count;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final previews = ref.watch(olderPreviewsProvider).value;
    return LibrarySection(
      label: 'Older',
      count: count,
      previewAssetIds: previews ?? const [],
      onViewAll: () => context.push('/older'),
    );
  }
}
