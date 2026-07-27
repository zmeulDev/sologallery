import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sologallery/core/database/app_database.dart';
import 'package:sologallery/core/database/daos/index_dao.dart'
    show FavoriteAsset;
import 'package:sologallery/core/database/database_provider.dart';
import 'package:sologallery/core/theme/app_theme.dart';
import 'package:sologallery/features/detail/photo_viewer_args.dart';
import 'package:sologallery/features/saved/saved_providers.dart';
import 'package:sologallery/features/saved/saved_screen.dart';
import 'package:sologallery/features/saved/widgets/masonry_grid_delegate.dart';
import 'package:sologallery/services/permission_provider.dart';
import 'package:sologallery/widgets/asset_thumbnail.dart';

import '../../support/asset_fixtures.dart';
import '../../support/fake_photo_library_service.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());

  // Drift's stream store schedules a zero-duration timer on dispose; settle it.
  Future<void> teardownTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('empty state invites favoriting', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          photoLibraryServiceProvider.overrideWithValue(
            FakePhotoLibraryService(),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const SavedScreen()),
      ),
    );
    await tester.pump();
    expect(find.text('No favorites yet'), findsOneWidget);
    await teardownTree(tester);
  });

  testWidgets('renders a grid cell per favorite', (tester) async {
    // Saved joins favorites to the photo_asset cache; seed both assets.
    await db.indexDao.upsertMetadata([
      for (final id in ['a1', 'a2'])
        (
          id: id,
          createdAt: DateTime(2024),
          isVideo: false,
          width: 1,
          height: 1,
          isDated: true,
        ),
    ]);
    await db.favoritesDao.add('a1', at: DateTime(2024, 1, 2));
    await db.favoritesDao.add('a2', at: DateTime(2024, 1, 1));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          photoLibraryServiceProvider.overrideWithValue(
            FakePhotoLibraryService(),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const SavedScreen()),
      ),
    );
    await tester.pump();
    expect(find.byType(AssetThumbnail), findsNWidgets(2));
    // A heart badge marks every favorite cell, and the bar shows the tally.
    expect(find.byIcon(Icons.favorite_rounded), findsNWidgets(2));
    expect(find.text('2 favorites'), findsOneWidget);
    await teardownTree(tester);
  });

  // The floating nav capsule reaches the screen as a bottom inset; without it
  // in the masonry's padding the last row of favorites hides behind the
  // capsule. See lib/widgets/nav_pill_bar.dart.
  testWidgets('the masonry clears the nav capsule', (tester) async {
    tester.view.padding = const FakeViewPadding(bottom: 96);
    addTearDown(tester.view.reset);
    final inset = 96 / tester.view.devicePixelRatio;

    await db.indexDao.upsertMetadata([
      (
        id: 'a1',
        createdAt: DateTime(2024),
        isVideo: false,
        width: 1,
        height: 1,
        isDated: true,
      ),
    ]);
    await db.favoritesDao.add('a1', at: DateTime(2024, 1, 2));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          photoLibraryServiceProvider.overrideWithValue(
            FakePhotoLibraryService(),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const SavedScreen()),
      ),
    );
    await tester.pump();

    final padding = tester.widget<SliverPadding>(find.byType(SliverPadding));
    expect(
      padding.padding.resolve(TextDirection.ltr).bottom,
      AppSpace.s16 + inset,
    );
    await teardownTree(tester);
  });

  testWidgets('lays favorites out in two columns keeping their shapes', (
    tester,
  ) async {
    // A landscape and a portrait: the grid must give them different heights,
    // and put them side by side rather than stacked.
    await db.indexDao.upsertMetadata([
      (
        id: 'wide',
        createdAt: DateTime(2024),
        isVideo: false,
        width: 4000,
        height: 3000,
        isDated: true,
      ),
      (
        id: 'tall',
        createdAt: DateTime(2024),
        isVideo: false,
        width: 3000,
        height: 4000,
        isDated: true,
      ),
    ]);
    await db.favoritesDao.add('wide', at: DateTime(2024, 1, 2));
    await db.favoritesDao.add('tall', at: DateTime(2024, 1, 1));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          photoLibraryServiceProvider.overrideWithValue(
            FakePhotoLibraryService(),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const SavedScreen()),
      ),
    );
    await tester.pump();

    final cells = tester.widgetList<AssetThumbnail>(
      find.byType(AssetThumbnail),
    );
    expect(cells.length, 2);
    final rects = find
        .byType(AssetThumbnail)
        .evaluate()
        .map((e) => tester.getRect(find.byWidget(e.widget)))
        .toList();
    // Side by side: same top edge, different left edges.
    expect(rects[0].top, rects[1].top);
    expect(rects[0].left, isNot(rects[1].left));
    // Equal widths, unequal heights — a masonry grid, not a square one.
    expect(rects[0].width, closeTo(rects[1].width, 0.01));
    expect(rects[0].height, isNot(closeTo(rects[1].height, 1)));
    await teardownTree(tester);
  });

  testWidgets('a single favorite reads in the singular', (tester) async {
    await db.indexDao.upsertMetadata([
      (
        id: 'a1',
        createdAt: DateTime(2024),
        isVideo: false,
        width: 1,
        height: 1,
        isDated: true,
      ),
    ]);
    await db.favoritesDao.add('a1', at: DateTime(2024, 1, 2));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          photoLibraryServiceProvider.overrideWithValue(
            FakePhotoLibraryService(),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const SavedScreen()),
      ),
    );
    await tester.pump();
    expect(find.text('1 favorite'), findsOneWidget);
    await teardownTree(tester);
  });

  testWidgets('error state shows a message', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          photoLibraryServiceProvider.overrideWithValue(
            FakePhotoLibraryService(),
          ),
          // Inject the error AsyncValue directly — deterministic, and avoids the
          // fake-async stream-delivery quirk in widget tests.
          savedFavoritesProvider.overrideWithValue(
            AsyncError<List<FavoriteAsset>>(
              Exception('boom'),
              StackTrace.empty,
            ),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const SavedScreen()),
      ),
    );
    await tester.pump();
    expect(find.text('Couldn\'t load your favorites'), findsOneWidget);
    await teardownTree(tester);
  });

  testWidgets(
    'a rebuild with unchanged favorite content keeps the same grid delegate',
    (tester) async {
      // The DB stream reconstructs the FavoriteAsset list on every emission, so
      // a benign rebuild (e.g. an unrelated provider re-emitting) must not hand
      // the sliver a *new* MasonryGridDelegate instance when the favorites'
      // content hasn't actually changed — that would defeat both
      // `shouldRelayout`'s identity guard and the delegate's own layout memo.
      final controller = StreamController<List<FavoriteAsset>>();
      addTearDown(controller.close);
      FavoriteAsset favorite() => (
        assetId: 'a1',
        favoritedAt: DateTime(2024, 1, 2),
        width: 100,
        height: 150,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            photoLibraryServiceProvider.overrideWithValue(
              FakePhotoLibraryService(),
            ),
            savedFavoritesProvider.overrideWith((ref) => controller.stream),
          ],
          child: MaterialApp(theme: AppTheme.light, home: const SavedScreen()),
        ),
      );

      // Two structurally-equal but separately-allocated lists, matching the
      // real DAO's behaviour of building a fresh list per emission.
      controller.add([favorite()]);
      await tester.pump();
      final firstDelegate =
          tester.widget<SliverGrid>(find.byType(SliverGrid)).gridDelegate
              as MasonryGridDelegate;

      controller.add([favorite()]);
      await tester.pump();
      final secondDelegate =
          tester.widget<SliverGrid>(find.byType(SliverGrid)).gridDelegate
              as MasonryGridDelegate;

      expect(identical(firstDelegate, secondDelegate), isTrue);
      await teardownTree(tester);
    },
  );

  testWidgets(
    'tapping a cached Saved cell pushes non-null initialBytes and the right '
    'assetIds/index',
    (tester) async {
      await db.indexDao.upsertMetadata([
        (
          id: 'a1',
          createdAt: DateTime(2024),
          isVideo: false,
          width: 100,
          height: 150,
          isDated: true,
        ),
        (
          id: 'a2',
          createdAt: DateTime(2024),
          isVideo: false,
          width: 150,
          height: 100,
          isDated: true,
        ),
      ]);
      // Newest-favorited first: 'a1' then 'a2'.
      await db.favoritesDao.add('a1', at: DateTime(2024, 1, 2));
      await db.favoritesDao.add('a2', at: DateTime(2024, 1, 1));

      Object? pushedExtra;
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(path: '/', builder: (_, _) => const SavedScreen()),
          // Captures the pushed `extra` so the test can inspect the
          // PhotoViewerArgs without depending on the real detail screen.
          GoRoute(
            path: '/photo/:id',
            builder: (_, state) {
              pushedExtra = state.extra;
              return const Scaffold(body: Text('photo-detail'));
            },
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            photoLibraryServiceProvider.overrideWithValue(
              FakePhotoLibraryService(
                thumbnailBytes: validThumbnailBytes,
              ),
            ),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: router,
          ),
        ),
      );
      // Thumbnails resolve during the initial settle, so the tap's cache read
      // hits data (populating `thumb.value`) rather than the loading state.
      await tester.pumpAndSettle();

      // Second cell in favorited order is 'a2', at index 1.
      await tester.tap(find.byType(AssetThumbnail).at(1));
      await tester.pumpAndSettle();

      expect(find.text('photo-detail'), findsOneWidget);
      final args = pushedExtra! as PhotoViewerArgs;
      expect(args.initialBytes, isNotNull);
      expect(args.assetIds, ['a1', 'a2']);
      expect(args.initialIndex, 1);
      await teardownTree(tester);
    },
  );
}
