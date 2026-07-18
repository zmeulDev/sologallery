import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../services/photo_library_service.dart';
import '../../widgets/asset_thumbnail.dart';
import '../detail/photo_viewer_args.dart';
import 'domain/year_month.dart';
import 'month_assets_provider.dart';

/// The full grid of every photo in one month (`/month/:key`), reached from a
/// month section's "View all". Cells are inert until the Phase 3 detail viewer.
class MonthGridScreen extends ConsumerWidget {
  const MonthGridScreen({super.key, required this.monthKey});

  /// The `YearMonth.key` from the route, e.g. `2026-07`.
  final String monthKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = YearMonth.tryParseKey(monthKey);
    if (month == null) {
      return const _InvalidMonth();
    }

    final assets = ref.watch(monthAssetsProvider(month));
    return Scaffold(
      appBar: AppBar(title: Text(month.label)),
      body: assets.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => const _CenteredNote('Couldn\'t load this month.'),
        data: (items) => items.isEmpty
            ? const _CenteredNote('No photos in this month.')
            : _Grid(month: month, items: items),
      ),
    );
  }
}

class _Grid extends ConsumerWidget {
  const _Grid({required this.month, required this.items});

  final YearMonth month;
  final List<AssetRef> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasMore = ref.watch(monthAssetsProvider(month).notifier).hasMore;
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.pixels >= n.metrics.maxScrollExtent - 800) {
          ref.read(monthAssetsProvider(month).notifier).loadMore();
        }
        return false;
      },
      child: GridView.builder(
        padding: const EdgeInsets.all(2),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 2,
          crossAxisSpacing: 2,
        ),
        itemCount: items.length + (hasMore ? 3 : 0),
        itemBuilder: (context, i) {
          if (i >= items.length) return const _CellPlaceholder();
          return GestureDetector(
            onTap: () => context.push(
              '/photo/${items[i].id}',
              extra: PhotoViewerArgs([for (final a in items) a.id], i),
            ),
            child: AssetThumbnail(
              assetId: items[i].id,
              size: 400,
              showVideoBadge: true,
            ),
          );
        },
      ),
    );
  }
}

class _CellPlaceholder extends StatelessWidget {
  const _CellPlaceholder();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    return ColoredBox(color: colors.surface2, child: const SizedBox.expand());
  }
}

class _InvalidMonth extends StatelessWidget {
  const _InvalidMonth();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: const _CenteredNote('That month couldn\'t be found.'),
    );
  }
}

class _CenteredNote extends StatelessWidget {
  const _CenteredNote(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final styles = Theme.of(context).extension<AppTextStyles>()!;
    return Center(
      child: Text(
        text,
        style: styles.body.copyWith(color: colors.textSecondary),
      ),
    );
  }
}
