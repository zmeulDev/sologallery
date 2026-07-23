import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format/count_labels.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_space.dart';
import '../../core/theme/app_text_styles.dart';
import '../../services/indexing_service.dart';
import '../../services/permission_provider.dart';
import '../../services/photo_library_service.dart';
import '../../widgets/asset_grid.dart';
import '../../widgets/asset_thumbnail.dart';
import '../../widgets/circle_icon_button.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/limited_access_banner.dart';
import '../../widgets/section_header.dart';
import '../detail/photo_viewer_args.dart';
import '../memories/widgets/memories_carousel.dart';
import 'domain/library_filter.dart';
import 'domain/library_timeline.dart';
import 'domain/year_month.dart';
import 'library_providers.dart';
import 'widgets/library_filter_bar.dart';
import 'widgets/year_header.dart';

/// Home gallery: photos grouped by time, newest first, read from the
/// `photo_asset` cache. The filter bar sets how coarsely — every month, the
/// last seven days, months under year heroes, or one section per year. Month
/// and year sections show up to six previews and a "View all" control.
class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(permissionProvider);
    final filter = ref.watch(libraryFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Library'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpace.s16),
            child: Center(
              child: CircleIconButton.surface(
                icon: Icons.settings_rounded,
                tooltip: 'Settings',
                onPressed: () => context.push('/settings'),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (access == PhotoAccess.limited)
            LimitedAccessBanner(
              onSelectMore: () =>
                  ref.read(permissionProvider.notifier).presentLimited(),
            ),
          const LibraryFilterBar(),
          // Each filter owns its own query, and so its own loading and empty
          // states — a shared `.when` would make the week wait on the month
          // counts it never reads.
          Expanded(
            child: switch (filter) {
              LibraryFilter.thisWeek => const _ThisWeekGrid(),
              LibraryFilter.year => const _YearList(),
              LibraryFilter.all ||
              LibraryFilter.months => _MonthTimeline(filter: filter),
            },
          ),
        ],
      ),
    );
  }
}

/// The month-grouped timeline, shown by both [LibraryFilter.all] and
/// [LibraryFilter.months] — they share every query and differ only in whether
/// years are announced and the memories carousel rides on top.
class _MonthTimeline extends ConsumerWidget {
  const _MonthTimeline({required this.filter});

  final LibraryFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final months = ref.watch(libraryMonthCountsProvider);
    final olderCount = ref.watch(olderCountProvider).value ?? 0;
    // Until the first metadata sweep runs, an empty cache is "not loaded yet",
    // not "no photos" — hold the spinner instead of flashing the empty state.
    final cacheReady = ref.watch(libraryCacheReadyProvider).value ?? false;

    return months.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => const EmptyState(
        title: 'Couldn\'t load your photos',
        detail:
            'Something went wrong reading your library. Pull to try '
            'again.',
      ),
      data: (counts) {
        if (counts.isEmpty && olderCount == 0) {
          return cacheReady
              ? const EmptyState(
                  title: 'No photos yet',
                  detail:
                      'Photos you take will appear here, grouped by '
                      'month.',
                )
              : const Center(child: CircularProgressIndicator());
        }
        return _MonthList(
          counts: counts,
          olderCount: olderCount,
          filter: filter,
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
      padding: EdgeInsets.only(
        top: AppSpace.s4,
        bottom: AppSpace.s24 + MediaQuery.paddingOf(context).bottom,
      ),
      itemCount: rows.length,
      itemBuilder: (context, i) {
        final row = rows[i];
        final child = switch (row) {
          MemoriesRow() => const MemoriesCarousel(),
          YearRow(:final year, :final count) => YearHeader(
            year: year,
            count: count,
          ),
          MonthRow(:final month, :final count) => _MonthSection(
            month: month,
            count: count,
          ),
          OlderRow(:final count) => _OlderSection(count: count),
        };
        return child;
      },
    );
  }
}

/// One section per calendar year, six previews each.
class _YearList extends ConsumerWidget {
  const _YearList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final years = ref.watch(libraryYearCountsProvider);
    final cacheReady = ref.watch(libraryCacheReadyProvider).value ?? false;

    return years.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => const EmptyState.note('Couldn\'t load your photos.'),
      data: (counts) {
        if (counts.isEmpty) {
          return cacheReady
              ? const EmptyState(
                  title: 'No photos yet',
                  detail: 'Photos you take will appear here, grouped by year.',
                )
              : const Center(child: CircularProgressIndicator());
        }
        return ListView.builder(
          padding: EdgeInsets.only(
            top: AppSpace.s4,
            bottom: AppSpace.s24 + MediaQuery.paddingOf(context).bottom,
          ),
          itemCount: counts.length,
          itemBuilder: (context, i) => _YearSection(entry: counts[i]),
        );
      },
    );
  }
}

/// One calendar-year section: the year hero over its six newest photos.
class _YearSection extends ConsumerWidget {
  const _YearSection({required this.entry});

  final YearCount entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final previews = ref.watch(yearPreviewsProvider(entry.year)).value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Like `_LibrarySection`, the gap between sections is owned by the top
        // edge alone, so it never adds up with the next section's.
        const SizedBox(height: AppSpace.s20),
        YearHeader(year: entry.year, count: entry.count),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.s8,
            AppSpace.s4,
            AppSpace.s8,
            0,
          ),
          child: _PreviewGrid(assetIds: previews ?? const []),
        ),
      ],
    );
  }
}

/// The rolling seven-day window as one flat scrolling grid — no sections,
/// because a week doesn't need dividing.
class _ThisWeekGrid extends ConsumerWidget {
  const _ThisWeekGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assets = ref.watch(thisWeekAssetsProvider);
    return assets.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => const EmptyState.note('Couldn\'t load this week.'),
      data: (items) => items.isEmpty
          ? const EmptyState.note('No photos in the last 7 days.')
          : AssetGrid(
              items: items,
              // The window is bounded by time, not paged — everything in it is
              // already here.
              hasMore: false,
              onLoadMore: () {},
            ),
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
    return _LibrarySection(
      label: month.label,
      count: count,
      previewAssetIds: previews ?? const [],
      onViewAll: () => context.push('/month/${month.key}'),
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
    return _LibrarySection(
      label: 'Older',
      count: count,
      previewAssetIds: previews ?? const [],
      onViewAll: () => context.push('/older'),
    );
  }
}

/// One Library section: a labelled header with a "View all" control over a
/// preview grid. Backs both calendar months and the trailing "Older" bucket.
class _LibrarySection extends StatelessWidget {
  const _LibrarySection({
    required this.label,
    required this.count,
    required this.previewAssetIds,
    required this.onViewAll,
  });

  final String label;
  final int count;
  final List<String> previewAssetIds;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
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
            child: SectionHeader(
              label: label,
              trailing: _SectionCount(count: count),
              onTap: onViewAll,
            ),
          ),
          const SizedBox(height: 10),
          _PreviewGrid(assetIds: previewAssetIds),
        ],
      ),
    );
  }
}

/// The quiet tally at the end of a section header. Says "items", not "photos" —
/// a calendar month mixes stills and video, and the grid below shows both.
class _SectionCount extends StatelessWidget {
  const _SectionCount({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final styles = Theme.of(context).extension<AppTextStyles>()!;
    return Text(
      itemCountLabel(count),
      style: styles.caption.copyWith(color: colors.textSecondary),
    );
  }
}

/// Up to six previews in a three-column grid. Tapping a cell opens the detail
/// viewer, swiping across this month's previews; the section header opens the
/// full month.
class _PreviewGrid extends StatelessWidget {
  const _PreviewGrid({required this.assetIds});

  final List<String> assetIds;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      // Explicit, and never null: a BoxScrollView with a null padding silently
      // absorbs MediaQuery.padding on its main axis. Inside the shell that
      // bottom inset is the floating nav capsule's height, so every preview
      // grid would append a capsule-sized band under itself — the whole gap
      // between one month's photos and the next month's header.
      padding: EdgeInsets.zero,
      // Wider than the edge-to-edge grids' `s2`: a preview grid is inset from
      // the screen edge, so its cells need a gutter that reads as deliberate
      // next to that margin rather than as a seam.
      mainAxisSpacing: AppSpace.s4,
      crossAxisSpacing: AppSpace.s4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (final (index, id) in assetIds.indexed)
          GestureDetector(
            onTap: () => context.push(
              '/photo/$id',
              extra: PhotoViewerArgs(assetIds, index),
            ),
            child: ClipRRect(
              borderRadius: AppRadius.br12,
              child: AssetThumbnail(
                assetId: id,
                size: 300,
                showVideoBadge: true,
              ),
            ),
          ),
      ],
    );
  }
}
