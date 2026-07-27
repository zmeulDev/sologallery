import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_radius.dart';
import '../../core/theme/app_space.dart';
import '../../core/theme/app_text_styles.dart';
import '../../services/indexing_service.dart';
import '../../services/permission_provider.dart';
import '../../services/photo_library_service.dart';
import '../../services/thumbnail_provider.dart';
import '../../widgets/asset_grid.dart' show kPhotoGridCacheExtent;
import '../../widgets/asset_thumbnail.dart';
import '../../widgets/circle_icon_button.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/limited_access_banner.dart';
import '../detail/detail_providers.dart';
import '../detail/photo_viewer_args.dart';
import '../memories/widgets/memories_carousel.dart';
import 'domain/library_filter.dart';
import 'domain/library_timeline.dart';
import 'domain/year_month.dart';
import 'library_providers.dart';
import 'widgets/library_filter_bar.dart';
import 'widgets/library_skeleton.dart';
import 'widgets/month_header.dart';
import 'widgets/section_count_pill.dart';
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
          // Each filter owns its own query, and so its own loading and empty
          // states — a shared `.when` would make the week wait on the month
          // counts it never reads. The filter bar lives inside each filter's
          // scrollable body so it sits immediately above the content it controls
          // and rides below the memories carousel on `All`.
          Expanded(
            child: KeyedSubtree(
              key: ValueKey(filter),
              child: switch (filter) {
                LibraryFilter.thisWeek => const _ThisWeekList(),
                LibraryFilter.year => const _YearList(),
                LibraryFilter.all ||
                LibraryFilter.months => _MonthTimeline(filter: filter),
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Padding shared by every Library scrollable so the floating nav capsule never
/// overlaps the last item.
EdgeInsets _libraryBottomPadding(BuildContext context) => EdgeInsets.only(
      top: AppSpace.s4,
      bottom: AppSpace.s24 + MediaQuery.paddingOf(context).bottom,
    );

/// The month-grouped timeline, shown by both [LibraryFilter.all] and
/// [LibraryFilter.months] — they share every query and differ only in whether
/// years are announced and the memories carousel rides on top.
class _MonthTimeline extends ConsumerWidget {
  const _MonthTimeline({required this.filter});

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
      error: (e, st) => _RefreshableBody(
        onRefresh: () => _refresh(ref),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: _libraryBottomPadding(context),
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
              ? _RefreshableBody(
                  onRefresh: () => _refresh(ref),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: _libraryBottomPadding(context),
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
        return _RefreshableBody(
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
      padding: _libraryBottomPadding(context),
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

/// One section per calendar year, six previews each.
class _YearList extends ConsumerWidget {
  const _YearList();

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(libraryYearCountsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final years = ref.watch(libraryYearCountsProvider);
    final cacheReady = ref.watch(libraryCacheReadyProvider).value ?? false;

    return years.when(
      loading: () => const LibrarySkeleton(),
      error: (e, st) => _RefreshableBody(
        onRefresh: () => _refresh(ref),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: _libraryBottomPadding(context),
          children: const [
            LibraryFilterBar(),
            EmptyState.note('Couldn\'t load your photos.'),
          ],
        ),
      ),
      data: (counts) {
        if (counts.isEmpty) {
          return cacheReady
              ? _RefreshableBody(
                  onRefresh: () => _refresh(ref),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: _libraryBottomPadding(context),
                    children: const [
                      LibraryFilterBar(),
                      EmptyState(
                        title: 'No photos yet',
                        detail: 'Photos you take will appear here, grouped by year.',
                      ),
                    ],
                  ),
                )
              : const LibrarySkeleton();
        }
        return _RefreshableBody(
          onRefresh: () => _refresh(ref),
          child: ListView.builder(
            padding: _libraryBottomPadding(context),
            itemCount: counts.length + 1,
            itemBuilder: (context, i) {
              if (i == 0) return const LibraryFilterBar();
              return RepaintBoundary(
                child: _YearSection(entry: counts[i - 1]),
              );
            },
          ),
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
        YearHeader(
          year: entry.year,
          count: entry.count,
          onTap: () => context.push('/year/${entry.year}'),
        ),
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

/// The rolling seven-day window grouped into one section per calendar day,
/// newest first, with the filter bar riding at the top.
class _ThisWeekList extends ConsumerWidget {
  const _ThisWeekList();

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(thisWeekDayCountsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = ref.watch(thisWeekDayCountsProvider);
    final cacheReady = ref.watch(libraryCacheReadyProvider).value ?? false;

    return days.when(
      loading: () => const LibrarySkeleton(),
      error: (e, st) => _RefreshableBody(
        onRefresh: () => _refresh(ref),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: _libraryBottomPadding(context),
          children: const [
            LibraryFilterBar(),
            EmptyState.note('Couldn\'t load this week.'),
          ],
        ),
      ),
      data: (counts) {
        if (counts.isEmpty) {
          return cacheReady
              ? _RefreshableBody(
                  onRefresh: () => _refresh(ref),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: _libraryBottomPadding(context),
                    children: const [
                      LibraryFilterBar(),
                      EmptyState.note('No photos in the last 7 days.'),
                    ],
                  ),
                )
              : const LibrarySkeleton();
        }
        return _RefreshableBody(
          onRefresh: () => _refresh(ref),
          child: ListView.builder(
            padding: _libraryBottomPadding(context),
            itemCount: counts.length + 1,
            itemBuilder: (context, i) {
              if (i == 0) return const LibraryFilterBar();
              final entry = counts[i - 1];
              return RepaintBoundary(
                child: _DaySection(day: entry.day, count: entry.count),
              );
            },
          ),
        );
      },
    );
  }
}

/// One calendar-day section under `This week`; its previews load lazily as the
/// day scrolls into view.
class _DaySection extends ConsumerWidget {
  const _DaySection({required this.day, required this.count});

  final DateTime day;
  final int count;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final previews = ref.watch(dayPreviewsProvider(day)).value;
    return _LibrarySection(
      label: formatDayHeader(day),
      count: count,
      previewAssetIds: previews ?? const [],
      onViewAll: () => context.push(
        '/day/${day.toIso8601String().split('T').first}',
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
          _PreviewGrid(assetIds: previews ?? const []),
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
    return _LibrarySection(
      label: 'Older',
      count: count,
      previewAssetIds: previews ?? const [],
      onViewAll: () => context.push('/older'),
    );
  }
}

/// One Library section: a labelled header with a count pill that opens the full
/// grid, over a preview grid. Backs calendar-day sections and the "Older" bucket.
class _LibrarySection extends StatelessWidget {
  const _LibrarySection({
    required this.label,
    required this.count,
    required this.previewAssetIds,
    this.onViewAll,
  });

  final String label;
  final int count;
  final List<String> previewAssetIds;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    final styles = Theme.of(context).extension<AppTextStyles>()!;
    final scheme = Theme.of(context).colorScheme;

    final header = Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.s8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label.toUpperCase(),
              style: styles.sectionLabel.copyWith(color: scheme.onSurface),
            ),
          ),
          SectionCountPill(count: count, showChevron: onViewAll != null),
        ],
      ),
    );

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
          if (onViewAll != null)
            Semantics(
              button: true,
              child: GestureDetector(
                // The row is mostly whitespace; without this only the label's
                // glyphs would answer a tap.
                behavior: HitTestBehavior.opaque,
                onTap: onViewAll,
                child: header,
              ),
            )
          else
            header,
          const SizedBox(height: 10),
          _PreviewGrid(assetIds: previewAssetIds),
        ],
      ),
    );
  }
}

/// Up to six previews in a three-column grid. Tapping a cell opens the detail
/// viewer, swiping across this month's previews; the section header opens the
/// full month.
///
/// Implemented with [Wrap] rather than a nested `GridView.count` with
/// `shrinkWrap: true` to avoid the extra intrinsic layout pass a scrollable
/// inside a `ListView` item forces on every frame.
class _PreviewGrid extends ConsumerWidget {
  const _PreviewGrid({required this.assetIds});

  final List<String> assetIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cellWidth = (constraints.maxWidth - 2 * AppSpace.s4) / 3;
        final thumbSize = (cellWidth * MediaQuery.devicePixelRatioOf(context))
            .ceil();
        return Wrap(
          spacing: AppSpace.s4,
          runSpacing: AppSpace.s4,
          children: [
            for (final (index, id) in assetIds.indexed)
              SizedBox(
                width: cellWidth,
                height: cellWidth,
                child: GestureDetector(
                  onTap: () {
                    final thumb = ref.read(
                      thumbnailProvider(
                        ThumbnailRequest(id, width: thumbSize, height: thumbSize),
                      ),
                    );
                    // Start the high-res fetch before the route push so the
                    // detail page is more likely to hit the in-memory cache.
                    ref
                        .read(photoLibraryServiceProvider)
                        .previewImage(id, kDetailImageMaxEdge)
                        .ignore();
                    context.push(
                      '/photo/${Uri.encodeComponent(id)}',
                      extra: PhotoViewerArgs(
                        assetIds,
                        index,
                        initialBytes: thumb.value,
                      ),
                    );
                  },
                  child: ClipRRect(
                    borderRadius: AppRadius.br12,
                    child: AssetThumbnail(
                      assetId: id,
                      size: thumbSize,
                      showVideoBadge: true,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Wraps a scrollable with a pull-to-refresh gesture. The child must itself be
/// a scrollable; the caller supplies `AlwaysScrollableScrollPhysics` on short or
/// empty lists so the gesture still registers.
class _RefreshableBody extends StatelessWidget {
  const _RefreshableBody({
    required this.onRefresh,
    required this.child,
  });

  final Future<void> Function() onRefresh;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: child,
    );
  }
}
