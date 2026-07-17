import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../services/permission_provider.dart';
import '../../services/photo_library_service.dart';
import '../../widgets/asset_thumbnail.dart';
import '../../widgets/limited_access_banner.dart';
import '../../widgets/month_section_header.dart';
import 'domain/month_summary.dart';
import 'library_providers.dart';

/// Home gallery: photos grouped by month, newest first. Each month shows up to
/// six previews and a "View all" control opening the full-month grid.
class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(permissionProvider);
    final months = ref.watch(libraryMonthsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Library'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search',
            onPressed: null, // wired in the search phase
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
              data: (sections) => sections.isEmpty
                  ? const _LibraryMessage(
                      title: 'No photos yet',
                      detail: 'Photos you take will appear here, grouped by '
                          'month.',
                    )
                  : _MonthList(sections: sections),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthList extends ConsumerWidget {
  const _MonthList({required this.sections});

  final List<MonthSummary> sections;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasMore = ref.watch(libraryMonthsProvider.notifier).hasMore;
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.pixels >= n.metrics.maxScrollExtent - 600) {
          ref.read(libraryMonthsProvider.notifier).loadMore();
        }
        return false;
      },
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 4, bottom: 24),
        itemCount: sections.length + (hasMore ? 1 : 0),
        itemBuilder: (context, i) {
          if (i >= sections.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }
          return _MonthSection(summary: sections[i]);
        },
      ),
    );
  }
}

class _MonthSection extends StatelessWidget {
  const _MonthSection({required this.summary});

  final MonthSummary summary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MonthSectionHeader(
            label: summary.month.label,
            trailing: _ViewAllButton(
              count: summary.count,
              onTap: () => context.push('/month/${summary.month.key}'),
            ),
          ),
          const SizedBox(height: 10),
          _PreviewGrid(assetIds: summary.previewAssetIds),
        ],
      ),
    );
  }
}

/// Up to six previews in a three-column grid. Cells are inert until the Phase 3
/// detail viewer; tapping "View all" opens the full month.
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
        for (final id in assetIds)
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: AssetThumbnail(assetId: id, size: 300),
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
