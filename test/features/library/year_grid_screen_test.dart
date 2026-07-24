import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/core/database/app_database.dart';
import 'package:sologallery/core/database/database_provider.dart';
import 'package:sologallery/core/theme/app_theme.dart';
import 'package:sologallery/features/library/year_grid_screen.dart';
import 'package:sologallery/services/permission_provider.dart';
import 'package:sologallery/services/photo_library_service.dart';
import 'package:sologallery/widgets/asset_thumbnail.dart';

import '../../support/asset_fixtures.dart';
import '../../support/fake_photo_library_service.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    String yearKey, {
    List<AssetRef> assets = const [],
  }) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.indexDao.upsertMetadata([
      for (final a in assets)
        (
          id: a.id,
          createdAt: a.createdAt,
          isVideo: false,
          width: 1,
          height: 1,
          isDated: true,
        ),
    ]);
    final fake = FakePhotoLibraryService(
      access: PhotoAccess.granted,
      assets: assets,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          photoLibraryServiceProvider.overrideWithValue(fake),
          databaseProvider.overrideWithValue(db),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: YearGridScreen(yearKey: yearKey),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> disposeTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('renders the year title and a grid of assets', (tester) async {
    await pump(tester, '2026', assets: assetsInMonth(2026, 8, 10));
    expect(find.widgetWithText(AppBar, '2026'), findsOneWidget);
    expect(find.byType(AssetThumbnail), findsAtLeastNWidgets(6));
    await disposeTree(tester);
  });

  testWidgets('empty year shows a note', (tester) async {
    await pump(tester, '2026');
    expect(find.text('No photos in this year.'), findsOneWidget);
    await disposeTree(tester);
  });

  testWidgets('invalid key shows a not-found note', (tester) async {
    await pump(tester, 'not-a-year');
    expect(find.text('That year couldn\'t be found.'), findsOneWidget);
    await disposeTree(tester);
  });
}
