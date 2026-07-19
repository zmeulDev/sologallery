import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/asset_grid.dart';
import 'month_assets_provider.dart';
import 'month_grid_screen.dart' show CenteredNote;

/// The full grid of undated photos (`/older`), reached from the Library's
/// trailing "Older" section — assets with no capture date, newest-added first.
class OlderGridScreen extends ConsumerWidget {
  const OlderGridScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assets = ref.watch(olderAssetsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Older')),
      body: assets.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => const CenteredNote('Couldn\'t load these photos.'),
        data: (items) => items.isEmpty
            ? const CenteredNote('No undated photos.')
            : AssetGrid(
                items: items,
                hasMore: ref.watch(olderAssetsProvider.notifier).hasMore,
                onLoadMore: () =>
                    ref.read(olderAssetsProvider.notifier).loadMore(),
              ),
      ),
    );
  }
}
