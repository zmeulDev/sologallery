import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderSliver;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sologallery/core/database/app_database.dart' show AppDatabase;
import 'package:sologallery/core/database/database_provider.dart';
import 'package:sologallery/core/theme/app_theme.dart';
import 'package:sologallery/services/permission_provider.dart';
import 'package:sologallery/services/photo_library_service.dart';
import 'package:sologallery/widgets/asset_thumbnail.dart';
import 'package:sologallery/widgets/folder_list.dart';

import '../support/fake_photo_library_service.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    List<DeviceFolder> folders, {
    double textScale = 1,
  }) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              // FolderList is a sliver (it builds lazily so a 30-folder device
              // does not decode and blur every cover up front), so it hosts in
              // a CustomScrollView, matching how AlbumsScreen mounts it.
              child: CustomScrollView(
                slivers: [FolderList(folders: folders)],
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/folder',
          builder: (_, state) => Scaffold(
            body: Text('folder-detail:${state.uri.queryParameters['id']}'),
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          photoLibraryServiceProvider.overrideWithValue(
            FakePhotoLibraryService(),
          ),
        ],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pump();
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  /// The tile's own box — the rounded clip every folder row draws itself into.
  Finder tileAt(int i) => find.byType(ClipRRect).at(i);

  testWidgets('renders nothing at all for no folders', (tester) async {
    await pump(tester, const []);
    expect(find.byType(ClipRRect), findsNothing);
    // A sliver has no box size to measure, so assert the extent it contributes
    // to its viewport instead. It needs `skipOffstage: false` to be found at
    // all: a viewport reports a zero-extent sliver as offstage, which is itself
    // the thing being asserted.
    expect(
      tester
          .renderObject<RenderSliver>(
            find.byType(FolderList, skipOffstage: false),
          )
          .geometry!
          .scrollExtent,
      0,
    );
    await settle(tester);
  });

  testWidgets('gives each folder its own tile, with its count', (tester) async {
    await pump(tester, const [
      DeviceFolder(id: 'cam', name: 'Camera', count: 1204),
      DeviceFolder(id: 'shots', name: 'Screenshots', count: 318),
      DeviceFolder(id: 'one', name: 'Scans', count: 1),
    ]);
    expect(find.byType(ClipRRect), findsNWidgets(3));
    expect(find.text('Camera'), findsOneWidget);
    expect(find.text('1204 photos'), findsOneWidget);
    expect(find.text('318 photos'), findsOneWidget);
    expect(find.text('1 photo'), findsOneWidget); // singular, not "1 photos"
    await settle(tester);
  });

  testWidgets('lays folders out two to a row', (tester) async {
    await pump(tester, const [
      DeviceFolder(id: 'cam', name: 'Camera', count: 12),
      DeviceFolder(id: 'shots', name: 'Screenshots', count: 8),
      DeviceFolder(id: 'scans', name: 'Scans', count: 3),
    ]);

    final first = tester.getRect(find.text('Camera'));
    final second = tester.getRect(find.text('Screenshots'));
    final third = tester.getRect(find.text('Scans'));

    // Side by side...
    expect(second.top, first.top);
    expect(second.left, greaterThan(first.left));
    // ...and the third wraps onto the next row, under the first.
    expect(third.top, greaterThan(first.top));
    expect(third.left, first.left);
    await settle(tester);
  });

  testWidgets('a tile is a short row, not a tall card', (tester) async {
    await pump(tester, const [
      DeviceFolder(id: 'cam', name: 'Camera', count: 12, coverAssetId: 'a1'),
      DeviceFolder(id: 'shots', name: 'Screenshots', count: 8),
    ]);

    final size = tester.getSize(tileAt(0));
    expect(size.height, 96); // half the old cover-card tile
    expect(size.width, greaterThan(size.height));
    await settle(tester);
  });

  testWidgets('the cover fills the tile as a blurred backdrop', (tester) async {
    // The cover is no longer what the folder is recognized by — the glyph and
    // the name are — so it runs edge to edge behind them, blurred.
    await pump(tester, const [
      DeviceFolder(id: 'cam', name: 'Camera', count: 12, coverAssetId: 'a1'),
    ]);

    expect(find.byType(ImageFiltered), findsOneWidget);
    expect(
      tester.getRect(find.byType(AssetThumbnail)),
      tester.getRect(tileAt(0)),
    );
    await settle(tester);
  });

  testWidgets('a coverless folder drops the backdrop, not the glyph', (
    tester,
  ) async {
    await pump(tester, const [
      DeviceFolder(id: 'shots', name: 'Screenshots', count: 8),
    ]);
    expect(find.byType(AssetThumbnail), findsNothing);
    expect(find.byType(ImageFiltered), findsNothing);
    expect(find.byIcon(Icons.folder_rounded), findsOneWidget);
    await settle(tester);
  });

  testWidgets('the glyph leads the name and count, all inside the tile', (
    tester,
  ) async {
    await pump(tester, const [
      DeviceFolder(id: 'cam', name: 'Camera', count: 12, coverAssetId: 'a1'),
    ]);

    final tile = tester.getRect(tileAt(0));
    final glyph = tester.getRect(find.byIcon(Icons.folder_rounded));
    final name = tester.getRect(find.text('Camera'));
    final count = tester.getRect(find.text('12 photos'));

    // Icon on the left, labels to its right and stacked.
    expect(glyph.right, lessThanOrEqualTo(name.left));
    expect(count.top, greaterThanOrEqualTo(name.bottom));
    // Labels live in the row now, not under it.
    for (final r in [glyph, name, count]) {
      expect(tile.contains(r.topLeft), isTrue);
      expect(tile.contains(r.bottomRight), isTrue);
    }
    // Bigger than the 14px mark the old tall tile wore in its corner.
    expect(glyph.height, greaterThanOrEqualTo(32));
    await settle(tester);
  });

  testWidgets('a doubled text scale grows the row instead of squashing it', (
    tester,
  ) async {
    await pump(tester, const [
      DeviceFolder(id: 'cam', name: 'Camera', count: 12),
    ], textScale: 2);

    expect(tester.getSize(tileAt(0)).height, greaterThan(96));
    expect(tester.takeException(), isNull); // no RenderFlex overflow
    await settle(tester);
  });

  testWidgets('tapping a folder opens its detail grid', (tester) async {
    await pump(tester, const [
      DeviceFolder(id: 'cam', name: 'Camera', count: 12),
    ]);
    await tester.tap(find.text('Camera'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('folder-detail:cam'), findsOneWidget);
    await settle(tester);
  });

  testWidgets('a folder id needing escaping still routes correctly', (
    tester,
  ) async {
    // iOS folder ids are PHAssetCollection local identifiers and contain "/",
    // which is why the route carries them as a query parameter.
    await pump(tester, const [
      DeviceFolder(id: 'ABC123/L0/040', name: 'Recents', count: 5),
    ]);
    await tester.tap(find.text('Recents'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('folder-detail:ABC123/L0/040'), findsOneWidget);
    await settle(tester);
  });
}
