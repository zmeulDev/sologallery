import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sologallery/core/database/app_database.dart';
import 'package:sologallery/core/database/database_provider.dart';
import 'package:sologallery/core/theme/app_theme.dart';
import 'package:sologallery/features/detail/photo_viewer_args.dart';
import 'package:sologallery/services/permission_provider.dart';
import 'package:sologallery/services/photo_library_service.dart';
import 'package:sologallery/widgets/asset_grid.dart';
import 'package:sologallery/widgets/asset_thumbnail.dart';

import '../support/asset_fixtures.dart';
import '../support/fake_photo_library_service.dart';

void main() {
  /// Renders [AssetGrid] alone behind a router whose `/photo/:id` route
  /// captures the pushed `extra` so the test can inspect the [PhotoViewerArgs]
  /// without depending on the real detail screen.
  Future<void> pump(
    WidgetTester tester, {
    required List<AssetRef> items,
    required FakePhotoLibraryService fake,
    bool hasMore = false,
    VoidCallback? onLoadMore,
    required ValueSetter<Object?> onPhotoPush,
  }) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: AssetGrid(
              items: items,
              hasMore: hasMore,
              onLoadMore: onLoadMore ?? () {},
            ),
          ),
        ),
        GoRoute(
          path: '/photo/:id',
          builder: (_, state) {
            onPhotoPush(state.extra);
            return const Scaffold(body: Text('photo-detail'));
          },
        ),
      ],
    );
    // AssetGrid always passes showVideoBadge: true, so AssetThumbnail's
    // videoDurationProvider needs a real (if empty) indexDaoProvider to check —
    // a cache miss resolves to "not a video", matching these plain-photo
    // fixtures.
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          photoLibraryServiceProvider.overrideWithValue(fake),
          databaseProvider.overrideWithValue(db),
        ],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'tapping a cell with a cached thumbnail pushes non-null initialBytes',
    (tester) async {
      final items = assetsInMonth(2026, 8, 3);
      final fake = FakePhotoLibraryService(
        assets: items,
        thumbnailBytes: validThumbnailBytes,
      );
      Object? pushedExtra;

      await pump(
        tester,
        items: items,
        fake: fake,
        onPhotoPush: (extra) => pushedExtra = extra,
      );

      // Thumbnails resolve during the initial settle, so the tap's cache read
      // hits data rather than the loading state.
      await tester.tap(find.byType(AssetThumbnail).at(1));
      await tester.pumpAndSettle();

      expect(find.text('photo-detail'), findsOneWidget);
      final args = pushedExtra;
      expect(args, isA<PhotoViewerArgs>());
      args as PhotoViewerArgs;
      expect(args.initialBytes, isNotNull);
      expect(args.assetIds, [for (final a in items) a.id]);
      expect(args.initialIndex, 1);
    },
  );

  testWidgets(
    'tapping a cell pre-warms the high-res preview before the push',
    (tester) async {
      final items = assetsInMonth(2026, 8, 2);
      final fake = FakePhotoLibraryService(
        assets: items,
        thumbnailBytes: validThumbnailBytes,
      );

      await pump(tester, items: items, fake: fake, onPhotoPush: (_) {});

      await tester.tap(find.byType(AssetThumbnail).first);
      await tester.pumpAndSettle();

      // kDetailImageMaxEdge (1440) — asserted by value so this test doesn't
      // depend on importing the detail-provider constant.
      expect(fake.previewMaxEdges, contains(1440));
    },
  );

  testWidgets(
    'tapping the last cell reports the correct index',
    (tester) async {
      final items = assetsInMonth(2026, 8, 4);
      final fake = FakePhotoLibraryService(
        assets: items,
        thumbnailBytes: validThumbnailBytes,
      );
      Object? pushedExtra;

      await pump(
        tester,
        items: items,
        fake: fake,
        onPhotoPush: (extra) => pushedExtra = extra,
      );

      await tester.tap(find.byType(AssetThumbnail).last);
      await tester.pumpAndSettle();

      final args = pushedExtra! as PhotoViewerArgs;
      expect(args.initialIndex, items.length - 1);
      expect(args.assetIds, [for (final a in items) a.id]);
    },
  );

  testWidgets(
    // Regression: iOS AssetEntity ids are paths like
    // `{uuid}/L0/001`; raw interpolation into `/photo/$id` produced a
    // three-segment path that GoRouter rejected as "Page Not Found". The fix
    // is `Uri.encodeComponent` at every `/photo/$id` call site — assert the
    // push reaches the route's `state.pathParameters['id']` after round-trip
    // decoding, matching the real id exactly.
    'iOS-shaped id (with `/L0/001`) reaches the photo route',
    (tester) async {
      // Mimic iOS AssetEntity id shape: `{uuid}/L0/001`.
      const iosPrefix = '603345BD-E05C-40D8-8A29-3335675F276B/L0/001';
      final items = assetsInMonth(2026, 8, 2, prefix: iosPrefix);
      final fake = FakePhotoLibraryService(
        assets: items,
        thumbnailBytes: validThumbnailBytes,
      );
      String? routedId;

      // Build a router that captures the routed path parameter (decoded by
      // GoRouter) so we can assert the iOS-shaped id round-trips correctly.
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => Scaffold(
              body: AssetGrid(
                items: items,
                hasMore: false,
                onLoadMore: () {},
              ),
            ),
          ),
          GoRoute(
            path: '/photo/:id',
            builder: (_, state) {
              routedId = state.pathParameters['id'];
              return const Scaffold(body: Text('photo-detail'));
            },
          ),
        ],
      );
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            photoLibraryServiceProvider.overrideWithValue(fake),
            databaseProvider.overrideWithValue(db),
          ],
          child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(AssetThumbnail).first);
      await tester.pumpAndSettle();

      expect(find.text('photo-detail'), findsOneWidget);
      expect(routedId, items.first.id);
    },
  );
}
