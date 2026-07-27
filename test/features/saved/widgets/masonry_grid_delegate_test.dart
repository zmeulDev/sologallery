import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/features/saved/widgets/masonry_grid_delegate.dart';

void main() {
  /// Minimal, otherwise-unused `SliverConstraints` — only `crossAxisExtent`
  /// varies between the calls under test.
  SliverConstraints constraintsWithExtent(double crossAxisExtent) {
    return SliverConstraints(
      axisDirection: AxisDirection.down,
      growthDirection: GrowthDirection.forward,
      userScrollDirection: ScrollDirection.idle,
      scrollOffset: 0,
      precedingScrollExtent: 0,
      overlap: 0,
      remainingPaintExtent: 600,
      crossAxisExtent: crossAxisExtent,
      crossAxisDirection: AxisDirection.right,
      viewportMainAxisExtent: 600,
      remainingCacheExtent: 600,
      cacheOrigin: 0,
    );
  }

  test(
    'reuses the layout when crossAxisExtent is unchanged across calls',
    () {
      final delegate = MasonryGridDelegate(
        items: [(width: 100, height: 150), (width: 100, height: 100)],
        columns: 2,
        gutter: 8,
      );
      final first = delegate.getLayout(constraintsWithExtent(200));
      final second = delegate.getLayout(constraintsWithExtent(200));
      // `RenderSliverGrid.performLayout` calls `getLayout` every frame; without
      // the memo this would be a fresh `_MasonryGridLayout` (and a fresh
      // `layoutMasonry` pass) each time.
      expect(identical(first, second), isTrue);
    },
  );

  test('recomputes the layout when crossAxisExtent changes', () {
    final delegate = MasonryGridDelegate(
      items: [(width: 100, height: 150), (width: 100, height: 100)],
      columns: 2,
      gutter: 8,
    );
    final first = delegate.getLayout(constraintsWithExtent(200));
    final second = delegate.getLayout(constraintsWithExtent(300));
    expect(identical(first, second), isFalse);
    // The new layout reflects the new width, not a stale cached one.
    expect(
      second.getGeometryForChildIndex(0).crossAxisExtent,
      isNot(first.getGeometryForChildIndex(0).crossAxisExtent),
    );
  });

  test(
    'a call at the original extent after a change recomputes again '
    '(cache holds only the most recent extent)',
    () {
      final delegate = MasonryGridDelegate(
        items: [(width: 100, height: 150), (width: 100, height: 100)],
        columns: 2,
        gutter: 8,
      );
      final first = delegate.getLayout(constraintsWithExtent(200));
      delegate.getLayout(constraintsWithExtent(300));
      final third = delegate.getLayout(constraintsWithExtent(200));
      expect(identical(first, third), isFalse);
    },
  );
}
