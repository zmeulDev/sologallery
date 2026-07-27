import 'dart:math' as math;

import 'package:flutter/rendering.dart';

import '../domain/masonry_layout.dart';

/// Drives a [SliverGrid] from [layoutMasonry], so a column-balanced grid stays
/// as lazy as a uniform one.
///
/// The arithmetic runs over every item up front — it is a few adds per item over
/// already-cached integers — but *building* stays windowed, because the layout
/// answers "which children touch this scroll offset" instead of the sliver
/// having to materialise children to find out. A `Column`-of-`Column`s masonry
/// would be far shorter and would build every favorite on first frame.
class MasonryGridDelegate extends SliverGridDelegate {
  MasonryGridDelegate({
    required this.items,
    required this.columns,
    required this.gutter,
  });

  /// Pixel dimensions per child, in the same order as the sliver's children.
  final List<({int width, int height})> items;

  final int columns;
  final double gutter;

  // `RenderSliverGrid.performLayout` calls `getLayout` on every layout pass —
  // i.e. every scroll frame, not just when the inputs change — so without a
  // memo this recomputed `layoutMasonry` (O(n) over every favorite) plus the
  // `_MasonryGridLayout` constructor's own O(n) `_columnMembers` pass on each
  // frame. `shouldRelayout` only gates whether the *sliver* asks again, not
  // whether this delegate is a fresh instance; caching here is what makes a
  // reused instance cheap to re-query.
  //
  // Keying on `crossAxisExtent` alone is safe because a delegate instance is
  // only ever reused while `items`/`columns`/`gutter` are unchanged — the
  // widget above hoists the delegate into `State` and only rebuilds it when
  // the favorites' content actually changes (see `_SavedGrid`). So across all
  // the frames a single instance sees, `crossAxisExtent` is the only input
  // that can vary.
  _MasonryGridLayout? _cachedLayout;
  double? _cachedExtent;

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    final cached = _cachedLayout;
    if (cached != null && _cachedExtent == constraints.crossAxisExtent) {
      return cached;
    }
    final layout = _MasonryGridLayout(
      layout: layoutMasonry(
        items: items,
        columns: columns,
        totalWidth: constraints.crossAxisExtent,
        gutter: gutter,
      ),
      columns: columns,
      gutter: gutter,
    );
    _cachedLayout = layout;
    _cachedExtent = constraints.crossAxisExtent;
    return layout;
  }

  @override
  bool shouldRelayout(MasonryGridDelegate oldDelegate) {
    return oldDelegate.columns != columns ||
        oldDelegate.gutter != gutter ||
        // Identity, not deep equality: the list is rebuilt from a stream on
        // every emission, and comparing thousands of records each relayout
        // would cost more than the relayout it avoids.
        !identical(oldDelegate.items, items);
  }
}

class _MasonryGridLayout extends SliverGridLayout {
  _MasonryGridLayout({
    required this.layout,
    required this.columns,
    required this.gutter,
  }) : _columnMembers = List.generate(columns, (_) => <int>[]) {
    for (var i = 0; i < layout.tiles.length; i++) {
      _columnMembers[layout.tiles[i].column].add(i);
    }
  }

  final MasonryLayout layout;
  final int columns;
  final double gutter;

  /// Child indices per column, ascending. Within one column both `top` and
  /// `top + height` increase with the index, which is what makes the binary
  /// searches below valid — globally only `top` is sorted.
  final List<List<int>> _columnMembers;

  @override
  double computeMaxScrollOffset(int childCount) => layout.extent;

  @override
  SliverGridGeometry getGeometryForChildIndex(int index) {
    final tile = layout.tiles[index];
    return SliverGridGeometry(
      scrollOffset: tile.top,
      crossAxisOffset: tile.column * (layout.columnWidth + gutter),
      mainAxisExtent: tile.height,
      crossAxisExtent: layout.columnWidth,
    );
  }

  @override
  int getMinChildIndexForScrollOffset(double scrollOffset) {
    // The first child that is still on screen is the earliest one whose bottom
    // edge has not passed the offset. Cells vary in height, so that child isn't
    // simply "the one before the first visible top" — a tall cell can start far
    // above and still be visible. Per column, though, bottoms ascend, so each
    // column can binary-search its own first survivor and the answer is the
    // earliest of those.
    var best = layout.tiles.length;
    for (final members in _columnMembers) {
      var lo = 0;
      var hi = members.length;
      while (lo < hi) {
        final mid = (lo + hi) ~/ 2;
        final tile = layout.tiles[members[mid]];
        if (tile.top + tile.height > scrollOffset) {
          hi = mid;
        } else {
          lo = mid + 1;
        }
      }
      if (lo < members.length) best = math.min(best, members[lo]);
    }
    // Nothing reaches the offset (scrolled past the end): clamp to a valid
    // index rather than returning a count.
    if (best == layout.tiles.length) {
      return math.max(0, layout.tiles.length - 1);
    }
    return best;
  }

  @override
  int getMaxChildIndexForScrollOffset(double scrollOffset) {
    // Tops ascend globally — `top` is the minimum of the column bottoms at the
    // moment a tile is placed, and those only grow — so the last child that has
    // started by this offset is a plain binary search over all tiles.
    final tiles = layout.tiles;
    if (tiles.isEmpty) return 0;
    var lo = 0;
    var hi = tiles.length - 1;
    var answer = 0;
    while (lo <= hi) {
      final mid = (lo + hi) ~/ 2;
      if (tiles[mid].top <= scrollOffset) {
        answer = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return answer;
  }
}
