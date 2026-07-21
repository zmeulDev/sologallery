import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/detail/detail_providers.dart';
import '../features/detail/domain/adjacent_ids.dart';

/// Warms [detailImageProvider] for the pages either side of [index] so a swipe
/// lands on already-decoded bytes instead of a spinner.
///
/// This is a *provider* warm-up, not a `precacheImage` call: the detail stage
/// renders `Image.memory` over bytes fetched by [detailImageProvider], so the
/// expensive part is that provider's `previewImage` platform round-trip, and
/// pre-decoding an `ImageProvider` would warm a cache the stage never reads.
///
/// It renders nothing. Being its own leaf widget is the point — the warm-up
/// subscriptions rebuild *this* zero-size widget when they resolve, rather
/// than the stage above it. [detailImageProvider] is `autoDispose`, so holding
/// the subscription here is exactly what keeps a neighbour's bytes alive
/// between the fetch and the swipe; dropping out of range disposes it again.
///
/// Videos are skipped — their page is a player, and their entry in
/// [detailImageProvider] would only ever be a poster frame nothing displays.
class PrecacheAdjacent extends ConsumerWidget {
  const PrecacheAdjacent({
    super.key,
    required this.assetIds,
    required this.index,
    this.radius = 1,
  });

  final List<String> assetIds;
  final int index;

  /// How many pages either side to warm. One is the useful default: each extra
  /// step is another full-size decode held in memory for a swipe that may
  /// never come.
  final int radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    for (final id in adjacentIds(assetIds, index, radius: radius)) {
      // Resolves from the same cache the page itself will read, so the swipe
      // is a cache hit rather than a re-fetch.
      final isVideo = ref.watch(isVideoProvider(id)).value;
      if (isVideo == false) ref.watch(detailImageProvider(id));
    }
    return const SizedBox.shrink();
  }
}
