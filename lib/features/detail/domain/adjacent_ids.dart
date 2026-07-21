/// Pure neighbour math for preloading around the visible page. No Flutter
/// imports — see `docs/spec.md#architecture`.
library;

/// The ids within [radius] positions of [index] in [ids], nearest first and
/// excluding [index] itself.
///
/// Nearest-first matters: the warm-up subscriptions are created in this order,
/// so the page the user is most likely to reach next starts fetching first.
/// Out-of-range positions are dropped rather than clamped — clamping would
/// return the *current* id at either end and warm a page that is already on
/// screen.
///
/// [index] itself may sit outside [ids], and still yields the neighbours that
/// don't. The memory player relies on this: its cursor counts a title card at
/// position -1 relative to the photo list, so `index: -1` correctly warms the
/// first photo — the single most valuable warm-up in the whole story, since
/// the title card is what's on screen while it loads.
List<String> adjacentIds(List<String> ids, int index, {int radius = 1}) {
  final out = <String>[];
  for (var step = 1; step <= radius; step++) {
    for (final i in [index + step, index - step]) {
      if (i >= 0 && i < ids.length) out.add(ids[i]);
    }
  }
  return out;
}
