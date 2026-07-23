import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/asset_grid.dart';
import '../../widgets/empty_state.dart';
import 'day_assets_provider.dart';
import 'domain/library_timeline.dart';

/// The full grid of every photo from one calendar day (`/day/:date`), reached
/// from a day section in the `This week` filter.
class DayGridScreen extends ConsumerWidget {
  const DayGridScreen({super.key, required this.dateKey});

  /// ISO date from the route, e.g. `2026-07-23`.
  final String dateKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = DateTime.tryParse(dateKey);
    if (day == null) {
      return const _InvalidDay();
    }

    final assets = ref.watch(dayAssetsProvider(day));
    return Scaffold(
      appBar: AppBar(title: Text(formatDayHeader(day))),
      body: assets.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => const EmptyState.note('Couldn\'t load this day.'),
        data: (items) => items.isEmpty
            ? const EmptyState.note('No photos on this day.')
            : AssetGrid(
                items: items,
                hasMore: ref.watch(dayAssetsProvider(day).notifier).hasMore,
                onLoadMore: () =>
                    ref.read(dayAssetsProvider(day).notifier).loadMore(),
              ),
      ),
    );
  }
}

class _InvalidDay extends StatelessWidget {
  const _InvalidDay();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: const EmptyState.note('That day couldn\'t be found.'),
    );
  }
}
