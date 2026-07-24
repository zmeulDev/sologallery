import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/core/theme/app_theme.dart';
import 'package:sologallery/widgets/asset_grid.dart';

/// The floating nav capsule is reported to the body as a bottom inset, so a
/// grid that ignores it hides its last row behind the capsule. [AssetGrid] is
/// shared by the Search tab (capsule visible) and the pushed month/album grids
/// (system inset only), so it has to add whatever the inset happens to be.
void main() {
  testWidgets('AssetGrid adds the bottom inset to its padding', (tester) async {
    tester.view.padding = const FakeViewPadding(bottom: 96);
    addTearDown(tester.view.reset);
    final inset = 96 / tester.view.devicePixelRatio;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          // Placeholder cells rather than real assets: a thumbnail would reach
          // for the photo_manager platform channel, which the host has none of.
          body: AssetGrid(items: const [], hasMore: true, onLoadMore: () {}),
        ),
      ),
    );
    await tester.pump();

    final grid = tester.widget<GridView>(find.byType(GridView));
    expect(grid.padding?.resolve(TextDirection.ltr).bottom,
        AppSpace.s4 + inset);
  });

  testWidgets('with no inset it keeps the plain grid gutter', (tester) async {
    tester.view.padding = FakeViewPadding.zero;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: AssetGrid(items: const [], hasMore: false, onLoadMore: () {}),
        ),
      ),
    );
    await tester.pump();

    final grid = tester.widget<GridView>(find.byType(GridView));
    expect(grid.padding?.resolve(TextDirection.ltr).bottom, AppSpace.s4);
  });
}
