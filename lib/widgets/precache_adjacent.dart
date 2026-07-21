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
/// It renders nothing — which makes it a trap inside a [Stack]: a Stack sizes
/// itself to its largest *non*-positioned child, so dropping this zero-size
/// widget into a stack whose other children are all positioned collapses that
/// stack to 0x0 and clips its whole subtree away. Wrap it in a [Positioned]
/// (or ensure the stack has another expanding child).
///
/// Being its own leaf widget is the point — the warm-up
/// subscriptions rebuild *this* zero-size widget when they resolve, rather
/// than the stage above it. [detailImageProvider] is `autoDispose`, so holding
/// the subscription here is exactly what keeps a neighbour's bytes alive
/// between the fetch and the swipe; dropping out of range disposes it again.
///
/// Videos are dropped once they're *known* to be videos — their page is a
/// player, and their entry in [detailImageProvider] would only ever be a
/// poster frame nothing displays.
class PrecacheAdjacent extends ConsumerWidget {
  const PrecacheAdjacent({
    super.key,
    required this.assetIds,
    required this.index,
    this.ahead = 1,
    this.behind = 1,
  });

  final List<String> assetIds;
  final int index;

  /// How many pages forward and back to warm — see [adjacentIds] on why the
  /// two differ. One each way is the default, for callers that advance a page
  /// at a time on their own schedule (the memory player): each extra step is
  /// another screen-capped preview held for a page that may never be reached.
  /// The detail viewer overrides both to 3, because a free swipe can outrun a
  /// one-deep window in a second and the payload is encoded bytes rather than
  /// decoded bitmaps.
  final int ahead;
  final int behind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    for (final id in adjacentIds(assetIds, index, ahead: ahead, behind: behind)) {
      // `!= true`, not `== false`: waiting for isVideoProvider to answer before
      // starting the fetch would serialize two platform round-trips on the one
      // path that has to be fast, and stills are the overwhelming majority.
      // Warm first, drop the entry once the asset is known to be a video.
      if (ref.watch(isVideoProvider(id)).value != true) {
        // Resolves from the same cache the page itself will read, so the swipe
        // is a cache hit rather than a re-fetch.
        ref.watch(detailImageProvider(id));
      }
    }
    return const SizedBox.shrink();
  }
}
