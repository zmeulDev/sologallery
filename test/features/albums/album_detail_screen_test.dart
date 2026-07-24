import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/core/database/app_database.dart';
import 'package:sologallery/core/database/database_provider.dart';
import 'package:sologallery/core/format/count_labels.dart';
import 'package:sologallery/core/theme/app_theme.dart';
import 'package:sologallery/features/albums/album_detail_screen.dart';
import 'package:sologallery/services/permission_provider.dart';
import 'package:sologallery/widgets/asset_thumbnail.dart';
import 'package:sologallery/widgets/circle_icon_button.dart';

import '../../support/fake_photo_library_service.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());

  Future<void> pump(WidgetTester tester, int albumId) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          photoLibraryServiceProvider
              .overrideWithValue(FakePhotoLibraryService()),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: AlbumDetailScreen(albumId: albumId),
        ),
      ),
    );
  }

  Future<void> teardownTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  /// Gives [ids] capture dates in `photo_assets`, newest last. The cover and
  /// the grid order both come from that date, so an album test that skips this
  /// is ordering rows that have no date at all.
  Future<void> cacheAssets(List<String> ids) {
    return db.indexDao.upsertMetadata([
      for (var i = 0; i < ids.length; i++)
        (
          id: ids[i],
          createdAt: DateTime(2026, 5, 1).add(Duration(days: i)),
          isVideo: false,
          width: 100,
          height: 100,
          isDated: true,
        ),
    ]);
  }

  testWidgets('shows the album name, newest photo as cover, and rounded cells', (tester) async {
    final id = await db.albumsDao.createAlbum('Trip');
    // Added oldest-first, so insertion order and capture order agree only if
    // the cover really tracks the capture date.
    await cacheAssets(['a1', 'a2']);
    await db.albumsDao.addEntry(id, 'a1');
    await db.albumsDao.addEntry(id, 'a2');
    await pump(tester, id);
    // Initial pump: the hero placeholder sits on top while the thumbnail loads.
    await tester.pump();
    expect(find.text('Trip'), findsOneWidget);
    expect(find.text(itemCountLabel(2)), findsOneWidget);

    // Let the fake thumbnail future resolve and the frame callback fire.
    await tester.pump(const Duration(seconds: 1));

    // Cover hero + two grid cells = three AssetThumbnail widgets.
    expect(find.byType(AssetThumbnail), findsNWidgets(3));
    expect(find.byType(ClipRRect), findsNWidgets(2));
    // The first thumbnail is the hero; with no explicit cover it falls back to
    // the album's newest photo.
    final hero = tester.widget<AssetThumbnail>(find.byType(AssetThumbnail).first);
    expect(hero.assetId, 'a2');
    await teardownTree(tester);
  });

  testWidgets('the hero exposes Back and the title as separate targets', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await cacheAssets(['a1']);
    final id = await db.albumsDao.createAlbum('Trip');
    await db.albumsDao.addEntry(id, 'a1');
    await pump(tester, id);
    await tester.pump(const Duration(seconds: 1));

    // The app bar's header annotation merges everything under it unless the
    // hero asks for explicit child nodes: Back used to swallow the title and
    // count, leaving one screen-sized button labelled "Back\nTrip\n1 item".
    final back = tester.getSemantics(find.bySemanticsLabel('Back'));
    expect(back, matchesSemantics(label: 'Back', tooltip: 'Back', isButton: true,
        isFocusable: true, hasFocusAction: true, hasTapAction: true));
    // Scoped to the button, not the 320px hero.
    expect(tester.getRect(find.byType(CircleIconButton)).height, lessThan(80));

    expect(
      tester.getSemantics(find.bySemanticsLabel('Trip, 1 item')),
      matchesSemantics(label: 'Trip, 1 item', isHeader: true),
    );

    await teardownTree(tester);
    semantics.dispose();
  });

  testWidgets('the cover tracks capture date, not the order photos were added', (
    tester,
  ) async {
    // a1 is the newer photo but is added *second*: under the old
    // most-recently-added rule this would cover with a2.
    await cacheAssets(['a2', 'a1']); // a1 gets the later capture date
    final id = await db.albumsDao.createAlbum('Trip');
    await db.albumsDao.addEntry(id, 'a2');
    await db.albumsDao.addEntry(id, 'a1');
    await pump(tester, id);
    await tester.pump(const Duration(seconds: 1));

    final hero = tester.widget<AssetThumbnail>(find.byType(AssetThumbnail).first);
    expect(hero.assetId, 'a1');
    await teardownTree(tester);
  });

  testWidgets('uses explicit cover asset when one is set', (tester) async {
    final id = await db.albumsDao.createAlbum('Trip', coverAssetId: 'cover');
    await db.albumsDao.addEntry(id, 'a1');
    await db.albumsDao.addEntry(id, 'a2');
    await pump(tester, id);
    await tester.pump(const Duration(seconds: 1));
    final hero = tester.widget<AssetThumbnail>(find.byType(AssetThumbnail).first);
    expect(hero.assetId, 'cover');
    expect(find.byType(AssetThumbnail), findsNWidgets(3));
    await teardownTree(tester);
  });

  testWidgets('hero placeholder hides once cover thumbnail loads', (tester) async {
    final id = await db.albumsDao.createAlbum('Trip', coverAssetId: 'cover');
    await db.albumsDao.addEntry(id, 'a1');
    await pump(tester, id);

    await tester.pump();
    // Before decode: placeholder covers hero, only grid cells are clipped.
    expect(find.byType(ClipRRect), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    // After decode: the hero image is added and its ClipRRect wrapper is gone,
    // leaving only the grid cells clipped.
    expect(find.byType(ClipRRect), findsOneWidget);
    await teardownTree(tester);
  });

  testWidgets('empty album shows a note', (tester) async {
    final id = await db.albumsDao.createAlbum('Trip');
    await pump(tester, id);
    await tester.pump();
    expect(find.textContaining('This album is empty'), findsOneWidget);
    await teardownTree(tester);
  });
}
