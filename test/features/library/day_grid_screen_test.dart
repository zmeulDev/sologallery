import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/core/database/app_database.dart';
import 'package:sologallery/core/database/database_provider.dart';
import 'package:sologallery/core/theme/app_theme.dart';
import 'package:sologallery/features/library/day_grid_screen.dart';
import 'package:sologallery/services/permission_provider.dart';
import 'package:sologallery/services/photo_library_service.dart';
import 'package:sologallery/widgets/asset_thumbnail.dart';

import '../../support/fake_photo_library_service.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    String dateKey, {
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
          home: DayGridScreen(dateKey: dateKey),
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

  testWidgets('renders the day title and a grid of assets', (tester) async {
    final day = DateTime(2026, 7, 23);
    await pump(
      tester,
      '2026-07-23',
      assets: [
        for (var i = 0; i < 10; i++)
          AssetRef(
            id: 'day-${day.day}-$i',
            createdAt: day.add(Duration(minutes: i)),
          ),
      ],
    );
    // The title is formatted via [formatDayHeader]. If the test runs on the
    // same calendar day as the mocked route, the label reads "Today".
    expect(
      find.widgetWithText(AppBar, 'Today'),
      findsOneWidget,
    );
    expect(find.byType(AssetThumbnail), findsAtLeastNWidgets(6));
    await disposeTree(tester);
  });

  testWidgets('empty day shows a note', (tester) async {
    await pump(tester, '2026-07-23');
    expect(find.text('No photos on this day.'), findsOneWidget);
    await disposeTree(tester);
  });

  testWidgets('invalid key shows a not-found note', (tester) async {
    await pump(tester, 'not-a-date');
    expect(find.text('That day couldn\'t be found.'), findsOneWidget);
    await disposeTree(tester);
  });
}
