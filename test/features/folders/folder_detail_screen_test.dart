import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sologallery/core/database/app_database.dart';
import 'package:sologallery/core/database/database_provider.dart';
import 'package:sologallery/core/theme/app_theme.dart';
import 'package:sologallery/features/folders/folder_detail_screen.dart';
import 'package:sologallery/services/permission_provider.dart';
import 'package:sologallery/services/photo_library_service.dart';
import 'package:sologallery/widgets/asset_thumbnail.dart';

import '../../support/asset_fixtures.dart';
import '../../support/fake_photo_library_service.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    String? folderName = 'Camera',
    List<AssetRef> assets = const [],
    bool fail = false,
  }) async {
    final router = GoRouter(
      initialLocation: '/folder',
      routes: [
        GoRoute(
          path: '/folder',
          builder: (_, _) =>
              FolderDetailScreen(folderId: 'cam', folderName: folderName),
        ),
      ],
    );
    // FolderDetailScreen's AssetGrid always passes showVideoBadge: true, so
    // videoDurationProvider needs a real (empty) indexDaoProvider to check —
    // a cache miss resolves to "not a video".
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          photoLibraryServiceProvider.overrideWithValue(
            FakePhotoLibraryService(folderAssetsById: {'cam': assets})
              ..failFolderAssets = fail,
          ),
          databaseProvider.overrideWithValue(db),
        ],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    // Bounded pumps — the loading branch's spinner never lets the tree settle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('shows the folder name and its photos', (tester) async {
    await pump(tester, assets: assetsInMonth(2026, 8, 4, prefix: 'cam'));

    expect(find.text('Camera'), findsOneWidget);
    expect(find.byType(AssetThumbnail), findsNWidgets(4));
  });

  testWidgets('falls back to "Folder" when the name is absent', (tester) async {
    await pump(
      tester,
      folderName: null,
      assets: assetsInMonth(2026, 8, 1, prefix: 'cam'),
    );

    expect(find.text('Folder'), findsOneWidget);
  });

  testWidgets('shows a spinner while the first page loads', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          photoLibraryServiceProvider
              .overrideWithValue(FakePhotoLibraryService()),
          databaseProvider.overrideWithValue(db),
        ],
        child: MaterialApp(
          theme: AppTheme.light, // CenteredNote reads the AppTextStyles extension
          home: const FolderDetailScreen(folderId: 'cam', folderName: 'Camera'),
        ),
      ),
    );
    // No pump past the async gap: the provider is still AsyncLoading.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('empty state when the folder has no photos', (tester) async {
    await pump(tester);

    expect(find.textContaining('empty'), findsOneWidget);
    expect(find.byType(AssetThumbnail), findsNothing);
  });

  testWidgets('error state when the folder cannot be read', (tester) async {
    // The service throws rather than the provider being overridden: an
    // AsyncNotifierProvider has no `overrideWithValue`, and unlike a
    // StreamProvider its Future-backed build() does surface the error under
    // fake-async.
    await pump(tester, fail: true);

    expect(find.textContaining('Couldn\'t load this folder'), findsOneWidget);
  });
}
