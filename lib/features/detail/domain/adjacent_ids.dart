/// Pure neighbour math for preloading around the visible page. No Flutter
/// imports — see `docs/spec.md#architecture`.
library;

/// The ids up to [ahead] positions after and [behind] positions before
/// [index] in [ids], nearest first and excluding [index] itself.
///
/// Nearest-first matters: the warm-up subscriptions are created in this order,
/// so the page the user is most likely to reach next starts fetching first.
/// Out-of-range positions are dropped rather than clamped — clamping would
/// return the *current* id at either end and warm a page that is already on
/// screen.
///
/// The two directions are separate because the two viewers move differently.
/// A swipe through the detail grid is genuinely two-way, so it warms one each
/// side. A memory is a story that runs forward — it is played, not browsed —
/// so the player spends its budget ahead and keeps only one page behind for
/// the occasional swipe back.
///
/// [index] itself may sit outside [ids], and still yields the neighbours that
/// don't. The memory player relies on this: its cursor counts a title card at
/// position -1 relative to the photo list, so `index: -1` warms the *opening*
/// photos — the most valuable warm-up in the whole story, since the title card
/// is what's on screen while they load.
List<String> adjacentIds(
  List<String> ids,
  int index, {
  int ahead = 1,
  int behind = 1,
}) {
  final out = <String>[];
  for (var step = 1; step <= (ahead > behind ? ahead : behind); step++) {
    if (step <= ahead && index + step >= 0 && index + step < ids.length) {
      out.add(ids[index + step]);
    }
    if (step <= behind && index - step >= 0 && index - step < ids.length) {
      out.add(ids[index - step]);
    }
  }
  return out;
}
