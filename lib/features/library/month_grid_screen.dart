import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/asset_grid.dart';
import '../../widgets/empty_state.dart';
import 'domain/year_month.dart';
import 'month_assets_provider.dart';

/// The full grid of every photo in one month (`/month/:key`), reached from a
/// month section's "View all".
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
        error: (e, st) => const EmptyState.note('Couldn\'t load this month.'),
        data: (items) => items.isEmpty
            ? const EmptyState.note('No photos in this month.')
            : AssetGrid(
                items: items,
                hasMore: ref.watch(monthAssetsProvider(month).notifier).hasMore,
                onLoadMore: () =>
                    ref.read(monthAssetsProvider(month).notifier).loadMore(),
              ),
      ),
    );
  }
}

class _InvalidMonth extends StatelessWidget {
  const _InvalidMonth();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: const EmptyState.note('That month couldn\'t be found.'),
    );
  }
}
