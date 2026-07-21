/// Column-balanced ("masonry") layout arithmetic for the Saved grid.
///
/// Pure Dart — no Flutter imports — so the placement rules are unit-testable
/// without a widget tree. The widget layer turns [MasonryTile]s into sliver
/// geometry; it decides nothing about where a tile goes.
library;

import 'dart:math' as math;

/// Where one cell lands: which column, how far down, and how tall.
class MasonryTile {
  const MasonryTile({
    required this.column,
    required this.top,
    required this.height,
  });

  /// Zero-based column index.
  final int column;

  /// Offset from the top of the grid, in logical pixels.
  final double top;

  final double height;

  @override
  bool operator ==(Object other) =>
      other is MasonryTile &&
      other.column == column &&
      other.top == top &&
      other.height == height;

  @override
  int get hashCode => Object.hash(column, top, height);

  @override
  String toString() =>
      'MasonryTile(column: $column, top: $top, height: $height)';
}

/// A laid-out grid: one tile per input item, plus the total scrollable height.
class MasonryLayout {
  const MasonryLayout({
    required this.tiles,
    required this.columnWidth,
    required this.extent,
  });

  final List<MasonryTile> tiles;

  /// Width of every column — cells differ in height only.
  final double columnWidth;

  /// Height of the tallest column: the grid's full scroll extent.
  final double extent;
}

/// The narrowest a cell may be drawn relative to its width (a tall portrait),
/// and the shortest (a wide panorama).
///
/// Real libraries contain 1:8 panoramas and screenshots of scrolling pages.
/// Honouring those literally gives one cell that is most of a screen tall, or a
/// letterbox slot too short to recognise anything in — either one wrecks the
/// two-column rhythm. Clamping trades exact fidelity for a scannable grid; the
/// full frame is one tap away.
const double _minAspect = 0.5; // 2:1 landscape
const double _maxAspect = 1.8; // taller than 1:1.8 portrait

/// Places [items] into [columns] columns, each cell keeping its aspect ratio,
/// by repeatedly filling whichever column is currently shortest.
///
/// Greedy-shortest-column rather than round-robin: alternating strictly would
/// let one tall photo push its column far past the other and leave a ragged gap
/// that never recovers, since order is fixed by favorite time and can't be
/// rebalanced by sorting.
///
/// [items] carries raw pixel dimensions; a non-positive dimension (a row cached
/// before its metadata resolved) falls back to square rather than dividing by
/// zero.
MasonryLayout layoutMasonry({
  required List<({int width, int height})> items,
  required int columns,
  required double totalWidth,
  required double gutter,
}) {
  assert(columns > 0, 'a grid needs at least one column');

  final columnWidth = (totalWidth - gutter * (columns - 1)) / columns;
  // A surface narrower than its own gutters would otherwise produce negative
  // cell widths and NaN heights downstream.
  final safeColumnWidth = math.max(0.0, columnWidth);

  final bottoms = List<double>.filled(columns, 0);
  final tiles = <MasonryTile>[];

  for (final item in items) {
    var shortest = 0;
    for (var c = 1; c < columns; c++) {
      if (bottoms[c] < bottoms[shortest]) shortest = c;
    }

    final aspect = (item.width > 0 && item.height > 0)
        ? (item.height / item.width).clamp(_minAspect, _maxAspect)
        : 1.0;
    final height = safeColumnWidth * aspect;
    final top = bottoms[shortest] == 0 ? 0.0 : bottoms[shortest] + gutter;

    tiles.add(MasonryTile(column: shortest, top: top, height: height));
    bottoms[shortest] = top + height;
  }

  return MasonryLayout(
    tiles: tiles,
    columnWidth: safeColumnWidth,
    extent: bottoms.isEmpty ? 0 : bottoms.reduce(math.max),
  );
}
