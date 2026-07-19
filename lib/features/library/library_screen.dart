import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../services/indexing_service.dart';
import '../../services/permission_provider.dart';
import '../../services/photo_library_service.dart';
import '../../widgets/asset_thumbnail.dart';
import '../../widgets/limited_access_banner.dart';
import '../../widgets/month_section_header.dart';
import '../detail/photo_viewer_args.dart';
import '../memories/widgets/memories_carousel.dart';
import 'library_providers.dart';

/// Home gallery: photos grouped by month, newest first, read from the
/// `photo_asset` cache. Each month shows up to six previews and a "View all"
/// control opening the full-month grid.
class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(permissionProvider);
    final months = ref.watch(libraryMonthCountsProvider);
    final olderCount = ref.watch(olderCountProvider).value ?? 0;
    // Until the first metadata sweep runs, an empty cache is "not loaded yet",
    // not "no photos" — hold the spinner instead of flashing the empty state.
    final cacheReady = ref.watch(libraryCacheReadyProvider).value ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Library'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
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
          Expanded(
            child: months.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => const _LibraryMessage(
                title: 'Couldn\'t load your photos',
                detail: 'Something went wrong reading your library. Pull to try '
                    'again.',
              ),
              data: (counts) {
                if (counts.isEmpty && olderCount == 0) {
                  return cacheReady
                      ? const _LibraryMessage(
                          title: 'No photos yet',
                          detail: 'Photos you take will appear here, grouped by '
                              'month.',
                        )
                      : const Center(child: CircularProgressIndicator());
                }
                return _MonthList(counts: counts, olderCount: olderCount);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthList extends StatelessWidget {
  const _MonthList({required this.counts, required this.olderCount});

  final List<MonthCount> counts;
  final int olderCount;

  @override
  Widget build(BuildContext context) {
    final showOlder = olderCount > 0;
    // Index 0 is the memories carousel; month sections shift down by one. The
    // carousel collapses to zero height when there are no memories, so no
    // special-casing is needed here.
    return ListView.builder(
      padding: const EdgeInsets.only(top: 4, bottom: 24),
      itemCount: 1 + counts.length + (showOlder ? 1 : 0),
      itemBuilder: (context, i) {
        if (i == 0) return const MemoriesCarousel();
        final index = i - 1;
        if (index >= counts.length) {
          return _OlderSection(count: olderCount);
        }
        return _MonthSection(entry: counts[index]);
      },
    );
  }
}

/// One calendar-month section; its previews load lazily from the cache as the
/// section scrolls into view.
class _MonthSection extends ConsumerWidget {
  const _MonthSection({required this.entry});

  final MonthCount entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final previews = ref.watch(monthPreviewsProvider(entry.month)).value;
    return _LibrarySection(
      label: entry.month.label,
      count: entry.count,
      previewAssetIds: previews ?? const [],
      onViewAll: () => context.push('/month/${entry.month.key}'),
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MonthSectionHeader(
            label: label,
            trailing: _ViewAllButton(count: count, onTap: onViewAll),
          ),
          const SizedBox(height: 10),
          _PreviewGrid(assetIds: previewAssetIds),
        ],
      ),
    );
  }
}

/// Up to six previews in a three-column grid. Tapping a cell opens the detail
/// viewer, swiping across this month's previews; "View all" opens the full month.
class _PreviewGrid extends StatelessWidget {
  const _PreviewGrid({required this.assetIds});

  final List<String> assetIds;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      mainAxisSpacing: 3,
      crossAxisSpacing: 3,
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
              borderRadius: BorderRadius.circular(4),
              child: AssetThumbnail(assetId: id, size: 300, showVideoBadge: true),
            ),
          ),
      ],
    );
  }
}

class _ViewAllButton extends StatelessWidget {
  const _ViewAllButton({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final text = Theme.of(context).extension<AppTextStyles>()!;
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: colors.textSecondary,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('View all $count', style: text.filterPill),
          const SizedBox(width: 2),
          const Icon(Icons.chevron_right, size: 16),
        ],
      ),
    );
  }
}

/// Centered title + supporting line for the empty and error states.
class _LibraryMessage extends StatelessWidget {
  const _LibraryMessage({required this.title, required this.detail});

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final text = Theme.of(context).extension<AppTextStyles>()!;
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: text.body.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: text.caption.copyWith(color: colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
