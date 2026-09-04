import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../services/indexing_service.dart';
import '../../../widgets/empty_state.dart';
import '../domain/library_timeline.dart';
import '../library_providers.dart';
import 'library_filter_bar.dart';
import 'library_bottom_padding.dart';
import 'library_section.dart';
import 'library_skeleton.dart';
import 'refreshable_body.dart';

/// The rolling seven-day window grouped into one section per calendar day,
/// newest first, with the filter bar riding at the top.
class ThisWeekList extends ConsumerWidget {
  const ThisWeekList({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(thisWeekDayCountsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = ref.watch(thisWeekDayCountsProvider);
    final cacheReady = ref.watch(libraryCacheReadyProvider).value ?? false;

    return days.when(
      loading: () => const LibrarySkeleton(),
      error: (e, st) => RefreshableBody(
        onRefresh: () => _refresh(ref),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: libraryBottomPadding(context),
          children: const [
            LibraryFilterBar(),
            EmptyState.note('Couldn\'t load this week.'),
          ],
        ),
      ),
      data: (counts) {
        if (counts.isEmpty) {
          return cacheReady
              ? RefreshableBody(
                  onRefresh: () => _refresh(ref),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: libraryBottomPadding(context),
                    children: const [
                      LibraryFilterBar(),
                      EmptyState.note('No photos in the last 7 days.'),
                    ],
                  ),
                )
              : const LibrarySkeleton();
        }
        return RefreshableBody(
          onRefresh: () => _refresh(ref),
          child: ListView.builder(
            padding: libraryBottomPadding(context),
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
    return LibrarySection(
      label: formatDayHeader(day),
      count: count,
      previewAssetIds: previews ?? const [],
      onViewAll: () => context.push(
        '/day/${day.toIso8601String().split('T').first}',
      ),
    );
  }
}
