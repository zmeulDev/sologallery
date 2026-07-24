import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/asset_grid.dart';
import '../../widgets/empty_state.dart';
import 'year_assets_provider.dart';

/// The full grid of every photo in one calendar year (`/year/:year`), reached
/// from the `Year` filter or from a year hero under `Months`.
class YearGridScreen extends ConsumerWidget {
  const YearGridScreen({super.key, required this.yearKey});

  /// The year from the route, e.g. `2026`.
  final String yearKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final year = int.tryParse(yearKey);
    if (year == null) {
      return const _InvalidYear();
    }

    final assets = ref.watch(yearAssetsProvider(year));
    return Scaffold(
      appBar: AppBar(title: Text('$year')),
      body: assets.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => const EmptyState.note('Couldn\'t load this year.'),
        data: (items) => items.isEmpty
            ? const EmptyState.note('No photos in this year.')
            : AssetGrid(
                items: items,
                hasMore: ref.watch(yearAssetsProvider(year).notifier).hasMore,
                onLoadMore: () =>
                    ref.read(yearAssetsProvider(year).notifier).loadMore(),
              ),
      ),
    );
  }
}

class _InvalidYear extends StatelessWidget {
  const _InvalidYear();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: const EmptyState.note('That year couldn\'t be found.'),
    );
  }
}
