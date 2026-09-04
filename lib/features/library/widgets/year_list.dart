import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_space.dart';
import '../../../services/indexing_service.dart';
import '../../../widgets/empty_state.dart';
import '../library_providers.dart';
import 'library_filter_bar.dart';
import 'library_bottom_padding.dart';
import 'library_skeleton.dart';
import 'preview_grid.dart';
import 'refreshable_body.dart';
import 'year_header.dart';

/// One section per calendar year, six previews each.
class YearList extends ConsumerWidget {
  const YearList({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(libraryYearCountsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final years = ref.watch(libraryYearCountsProvider);
    final cacheReady = ref.watch(libraryCacheReadyProvider).value ?? false;

    return years.when(
      loading: () => const LibrarySkeleton(),
      error: (e, st) => RefreshableBody(
        onRefresh: () => _refresh(ref),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: libraryBottomPadding(context),
          children: const [
            LibraryFilterBar(),
            EmptyState.note('Couldn\'t load your photos.'),
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
                      EmptyState(
                        title: 'No photos yet',
                        detail: 'Photos you take will appear here, grouped by year.',
                      ),
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
        // Like `LibrarySection`, the gap between sections is owned by the top
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
          child: PreviewGrid(assetIds: previews ?? const []),
        ),
      ],
    );
  }
}
