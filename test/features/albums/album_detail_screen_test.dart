import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/core/database/app_database.dart';
import 'package:sologallery/core/database/database_provider.dart';
import 'package:sologallery/core/theme/app_theme.dart';
import 'package:sologallery/features/albums/album_detail_screen.dart';
import 'package:sologallery/services/permission_provider.dart';
import 'package:sologallery/widgets/asset_thumbnail.dart';

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

  testWidgets('shows the album name and a cell per entry', (tester) async {
    final id = await db.albumsDao.createAlbum('Trip');
    await db.albumsDao.addEntry(id, 'a1');
    await db.albumsDao.addEntry(id, 'a2');
    await pump(tester, id);
    await tester.pump();
    expect(find.widgetWithText(AppBar, 'Trip'), findsOneWidget);
    expect(find.byType(AssetThumbnail), findsNWidgets(2));
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
