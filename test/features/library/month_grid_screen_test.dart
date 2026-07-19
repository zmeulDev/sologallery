import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/core/database/app_database.dart';
import 'package:sologallery/core/database/database_provider.dart';
import 'package:sologallery/core/theme/app_theme.dart';
import 'package:sologallery/features/library/month_grid_screen.dart';
import 'package:sologallery/services/permission_provider.dart';
import 'package:sologallery/services/photo_library_service.dart';
import 'package:sologallery/widgets/asset_thumbnail.dart';

import '../../support/asset_fixtures.dart';
import '../../support/fake_photo_library_service.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    String monthKey, {
    List<AssetRef> assets = const [],
  }) async {
    // The grid paginates the photo_asset cache; seed it. The fake still backs
    // per-cell thumbnails.
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
          home: MonthGridScreen(monthKey: monthKey),
        ),
      ),
    );
    // The grid now watches a live Drift stream — bounded pumps (a `.when`
    // loading spinner never settles under `pumpAndSettle`); the stream emits
    // the seeded rows within a frame.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  /// Tears down the tree and elapses time so Drift's stream-close zero-timer
  /// doesn't trip the pending-timer teardown invariant (must run in the body,
  /// before addTearDown callbacks).
  Future<void> disposeTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('renders the month title and a grid of assets', (tester) async {
    await pump(tester, '2026-08', assets: assetsInMonth(2026, 8, 10));
    expect(find.widgetWithText(AppBar, 'August 2026'), findsOneWidget);
    // GridView is lazy — assert the visible rows built (not all 10).
    expect(find.byType(AssetThumbnail), findsAtLeastNWidgets(6));
    await disposeTree(tester);
  });

  testWidgets('empty month shows a note', (tester) async {
    await pump(tester, '2026-08');
    expect(find.text('No photos in this month.'), findsOneWidget);
    await disposeTree(tester);
  });

  testWidgets('invalid key shows a not-found note', (tester) async {
    await pump(tester, 'not-a-month');
    expect(find.text('That month couldn\'t be found.'), findsOneWidget);
    await disposeTree(tester);
  });
}
