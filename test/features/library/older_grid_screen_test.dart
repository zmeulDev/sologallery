import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/core/database/app_database.dart';
import 'package:sologallery/core/database/database_provider.dart';
import 'package:sologallery/core/theme/app_theme.dart';
import 'package:sologallery/features/library/older_grid_screen.dart';
import 'package:sologallery/services/permission_provider.dart';
import 'package:sologallery/services/photo_library_service.dart';
import 'package:sologallery/widgets/asset_thumbnail.dart';

import '../../support/asset_fixtures.dart';
import '../../support/fake_photo_library_service.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    List<AssetRef> undatedAssets = const [],
  }) async {
    // The Older grid paginates the undated (is_dated=false) cache rows.
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.indexDao.upsertMetadata([
      for (final a in undatedAssets)
        (
          id: a.id,
          createdAt: a.createdAt,
          isVideo: false,
          width: 1,
          height: 1,
          isDated: false,
        ),
    ]);
    final fake = FakePhotoLibraryService(
      access: PhotoAccess.granted,
      undatedAssets: undatedAssets,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          photoLibraryServiceProvider.overrideWithValue(fake),
          databaseProvider.overrideWithValue(db),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const OlderGridScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders the Older title and a grid of undated assets',
      (tester) async {
    await pump(tester, undatedAssets: assetsInMonth(2020, 1, 10));
    expect(find.widgetWithText(AppBar, 'Older'), findsOneWidget);
    expect(find.byType(AssetThumbnail), findsAtLeastNWidgets(6));
  });

  testWidgets('empty Older grid shows a note', (tester) async {
    await pump(tester);
    expect(find.text('No undated photos.'), findsOneWidget);
  });
}
