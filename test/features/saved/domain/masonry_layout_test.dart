import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/features/saved/domain/masonry_layout.dart';

void main() {
  /// A square-ish item of the given pixel size.
  ({int width, int height}) item(int w, int h) => (width: w, height: h);

  group('column width', () {
    test('splits the width and subtracts the gutters between columns', () {
      // 2 columns, one 10px gutter between them: (210 - 10) / 2.
      final layout = layoutMasonry(
        items: [item(1, 1)],
        columns: 2,
        totalWidth: 210,
        gutter: 10,
      );
      expect(layout.columnWidth, 100);
    });

    test('three columns subtract two gutters, not three', () {
      final layout = layoutMasonry(
        items: const [],
        columns: 3,
        totalWidth: 320,
        gutter: 10,
      );
      expect(layout.columnWidth, 100);
    });

    test('never returns a negative width when the surface is tiny', () {
      final layout = layoutMasonry(
        items: [item(1, 1)],
        columns: 2,
        totalWidth: 4,
        gutter: 40,
      );
      expect(layout.columnWidth, 0);
      // A zero width must still yield a finite height, not NaN.
      expect(layout.tiles.single.height, 0);
    });
  });

  group('placement', () {
    test('is empty for no items', () {
      final layout = layoutMasonry(
        items: const [],
        columns: 2,
        totalWidth: 200,
        gutter: 0,
      );
      expect(layout.tiles, isEmpty);
      expect(layout.extent, 0);
    });

    test(
      'fills every column before stacking, and the first row has no gutter',
      () {
        final layout = layoutMasonry(
          items: [item(1, 1), item(1, 1), item(1, 1)],
          columns: 2,
          totalWidth: 200,
          gutter: 0,
        );
        expect(layout.tiles[0].column, 0);
        expect(layout.tiles[1].column, 1);
        // Both start flush at the top; only the third stacks.
        expect(layout.tiles[0].top, 0);
        expect(layout.tiles[1].top, 0);
        expect(layout.tiles[2].column, 0);
        expect(layout.tiles[2].top, 100);
      },
    );

    test('puts a gutter between stacked cells but never above the first', () {
      final layout = layoutMasonry(
        items: [item(1, 1), item(1, 1), item(1, 1), item(1, 1)],
        columns: 2,
        totalWidth: 210,
        gutter: 10,
      );
      expect(layout.tiles[0].top, 0);
      expect(layout.tiles[1].top, 0);
      // 100 tall + 10 gutter.
      expect(layout.tiles[2].top, 110);
      expect(layout.tiles[3].top, 110);
    });

    test(
      'sends each item to the currently shortest column, not round-robin',
      () {
        // A tall first cell (2:1 portrait) must not force the next two to
        // alternate back into it while column 1 is still empty.
        final layout = layoutMasonry(
          items: [item(100, 150), item(100, 100), item(100, 100)],
          columns: 2,
          totalWidth: 200,
          gutter: 0,
        );
        expect(layout.tiles[0].column, 0); // 150 tall
        expect(layout.tiles[1].column, 1); // 100 tall
        // Column 1 is at 100, column 0 at 150 — the third goes to column 1.
        expect(layout.tiles[2].column, 1);
        expect(layout.tiles[2].top, 100);
      },
    );

    test(
      'tops never decrease, which is what the sliver binary-searches on',
      () {
        final layout = layoutMasonry(
          items: [
            item(100, 180),
            item(100, 60),
            item(100, 120),
            item(100, 90),
            item(100, 200),
            item(100, 50),
          ],
          columns: 2,
          totalWidth: 200,
          gutter: 8,
        );
        for (var i = 1; i < layout.tiles.length; i++) {
          expect(
            layout.tiles[i].top,
            greaterThanOrEqualTo(layout.tiles[i - 1].top),
            reason: 'tile $i starts above tile ${i - 1}',
          );
        }
      },
    );

    test('cells in one column never overlap', () {
      final layout = layoutMasonry(
        items: [
          for (final h in [180, 60, 120, 90, 200, 50, 140]) item(100, h),
        ],
        columns: 2,
        totalWidth: 200,
        gutter: 8,
      );
      for (var column = 0; column < 2; column++) {
        final inColumn = layout.tiles.where((t) => t.column == column).toList();
        for (var i = 1; i < inColumn.length; i++) {
          expect(
            inColumn[i].top,
            greaterThanOrEqualTo(inColumn[i - 1].top + inColumn[i - 1].height),
          );
        }
      }
    });
  });

  group('aspect ratio', () {
    test('keeps a cell\'s own proportions', () {
      final layout = layoutMasonry(
        items: [item(100, 150)],
        columns: 1,
        totalWidth: 200,
        gutter: 0,
      );
      expect(layout.tiles.single.height, 300); // 200 * 1.5
    });

    test('clamps a panorama so it cannot become a letterbox sliver', () {
      final layout = layoutMasonry(
        items: [item(4000, 500)], // 1:8, far past the floor
        columns: 1,
        totalWidth: 200,
        gutter: 0,
      );
      expect(layout.tiles.single.height, 100); // 200 * 0.5, the minimum
    });

    test('clamps a very tall photo so it cannot swallow the screen', () {
      final layout = layoutMasonry(
        items: [item(500, 4000)], // 8:1, far past the ceiling
        columns: 1,
        totalWidth: 200,
        gutter: 0,
      );
      expect(layout.tiles.single.height, 360); // 200 * 1.8, the maximum
    });

    test('treats a zero or missing dimension as square rather than dividing by '
        'zero', () {
      final layout = layoutMasonry(
        items: [item(0, 0), item(100, 0), item(-5, 10)],
        columns: 1,
        totalWidth: 200,
        gutter: 0,
      );
      for (final tile in layout.tiles) {
        expect(tile.height, 200);
      }
    });
  });

  group('extent', () {
    test('is the tallest column, not the sum of all cells', () {
      final layout = layoutMasonry(
        items: [item(1, 1), item(1, 1)],
        columns: 2,
        totalWidth: 200,
        gutter: 0,
      );
      // Side by side: 100 each, so the grid is 100 tall — not 200.
      expect(layout.extent, 100);
    });

    test('accounts for the gutters it inserted', () {
      final layout = layoutMasonry(
        items: [item(1, 1), item(1, 1), item(1, 1)],
        columns: 1,
        totalWidth: 100,
        gutter: 10,
      );
      // 100 + 10 + 100 + 10 + 100.
      expect(layout.extent, 320);
    });
  });
}
