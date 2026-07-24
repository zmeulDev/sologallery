import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sologallery/core/database/daos/albums_dao.dart'
    show AlbumSummary;
import 'package:sologallery/core/theme/app_theme.dart';
import 'package:sologallery/features/albums/widgets/album_card.dart';
import 'package:sologallery/services/permission_provider.dart';
import 'package:sologallery/widgets/asset_grid.dart';
import 'package:sologallery/widgets/asset_thumbnail.dart';
import 'package:sologallery/widgets/cover_row.dart';

import '../support/asset_fixtures.dart';
import '../support/fake_photo_library_service.dart';

/// One radius for every photo in the app. The reported bug was that the "This
/// week" grid's cells had no rounding at all while the month previews did, so
/// this asserts the invariant across every surface that shows a thumbnail
/// rather than re-checking one of them.
void main() {
  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          photoLibraryServiceProvider.overrideWithValue(
            FakePhotoLibraryService(),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: GoRouter(
            routes: [
              GoRoute(path: '/', builder: (_, _) => Scaffold(body: child)),
              GoRoute(
                path: '/photo/:id',
                builder: (_, _) => const Scaffold(body: Text('photo')),
              ),
              GoRoute(
                path: '/folder',
                builder: (_, _) => const Scaffold(body: Text('folder')),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// Every thumbnail on screen, with the radius of the nearest `ClipRRect`
  /// above it. A thumbnail with no clip at all reports `null`, which is the
  /// exact shape of the original bug.
  List<BorderRadius?> radiiOfThumbnails(WidgetTester tester) {
    return [
      for (final element in find.byType(AssetThumbnail).evaluate())
        () {
          BorderRadius? found;
          element.visitAncestorElements((ancestor) {
            final widget = ancestor.widget;
            if (widget is ClipRRect) {
              found = widget.borderRadius as BorderRadius?;
              return false;
            }
            // Stop at the screen root so a page-level clip can't be mistaken
            // for the cell's own.
            return widget is! Scaffold;
          });
          return found;
        }(),
    ];
  }

  void expectAllRadius(
    WidgetTester tester, {
    required int count,
    BorderRadius radius = AppRadius.br12,
  }) {
    final radii = radiiOfThumbnails(tester);
    expect(radii, hasLength(count));
    expect(radii, everyElement(radius));
  }

  void expectAllBr12(WidgetTester tester, {required int count}) =>
      expectAllRadius(tester, count: count);

  testWidgets('AssetGrid cells clip to br12', (tester) async {
    // Backs "This week", the month grid, the older grid, search results, album
    // detail and folder detail — one fix covers all six.
    await pump(
      tester,
      AssetGrid(
        items: assetsInMonth(2026, 8, 6),
        hasMore: false,
        onLoadMore: () {},
      ),
    );
    expectAllBr12(tester, count: 6);
  });

  testWidgets('AssetGrid placeholder cells clip to br12 too', (tester) async {
    // Otherwise the still-loading tail of a page is visibly square next to the
    // rounded rows above it.
    await pump(
      tester,
      AssetGrid(
        items: assetsInMonth(2026, 8, 3),
        hasMore: true,
        onLoadMore: () {},
      ),
    );
    final clips = tester
        .widgetList<ClipRRect>(find.byType(ClipRRect))
        .map((c) => c.borderRadius)
        .toList();
    // 3 cells + 3 trailing placeholders.
    expect(clips.where((r) => r == AppRadius.br12), hasLength(6));
  });

  testWidgets('CoverRow covers clip to br12', (tester) async {
    await pump(
      tester,
      CoverRow(
        coverAssetId: 'a1',
        name: 'Camera',
        count: 12,
        onTap: () {},
      ),
    );
    expectAllBr12(tester, count: 1);
  });

  testWidgets('AlbumCard covers clip to br30', (tester) async {
    // The album card is the documented exception to the r12 thumbnail rule:
    // the cover fills the card, so it takes the card's own r30 rather than
    // sitting inside it as a thumbnail. Same for the People strip's card.
    await pump(
      tester,
      const SizedBox(
        width: 180,
        height: 220,
        child: AlbumCard(
          summary: AlbumSummary(
            id: 1,
            name: 'Trip',
            entryCount: 8,
            coverAssetId: 'a1',
          ),
        ),
      ),
    );
    expectAllRadius(tester, count: 1, radius: AppRadius.br30);
  });

}
