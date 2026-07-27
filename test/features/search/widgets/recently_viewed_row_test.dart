import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sologallery/core/theme/app_theme.dart';
import 'package:sologallery/features/detail/photo_viewer_args.dart';
import 'package:sologallery/features/search/widgets/recently_viewed_row.dart';
import 'package:sologallery/services/permission_provider.dart';
import 'package:sologallery/widgets/asset_thumbnail.dart';

import '../../../support/asset_fixtures.dart';
import '../../../support/fake_photo_library_service.dart';

void main() {
  /// Renders [RecentlyViewedRow] alone behind a router whose `/photo/:id`
  /// route captures the pushed `extra` so the test can inspect the
  /// [PhotoViewerArgs] without depending on the real detail screen.
  Future<void> pump(
    WidgetTester tester, {
    required List<String> assetIds,
    required FakePhotoLibraryService fake,
    required ValueSetter<Object?> onPhotoPush,
  }) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: RecentlyViewedRow(assetIds: assetIds),
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
    await tester.pumpWidget(
      ProviderScope(
        overrides: [photoLibraryServiceProvider.overrideWithValue(fake)],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'tapping a recent cell with a cached thumbnail pushes non-null '
    'initialBytes for that asset only',
    (tester) async {
      final assetIds = ['a', 'b', 'c'];
      final fake = FakePhotoLibraryService(
        thumbnailBytes: validThumbnailBytes,
      );
      Object? pushedExtra;

      await pump(
        tester,
        assetIds: assetIds,
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
      expect(args.assetIds, ['b']);
      expect(args.initialIndex, 0);
    },
  );

  testWidgets(
    'tapping a recent cell pre-warms the high-res preview before the push',
    (tester) async {
      final assetIds = ['a', 'b', 'c'];
      final fake = FakePhotoLibraryService(
        thumbnailBytes: validThumbnailBytes,
      );

      await pump(tester, assetIds: assetIds, fake: fake, onPhotoPush: (_) {});

      await tester.tap(find.byType(AssetThumbnail).first);
      await tester.pumpAndSettle();

      // kDetailImageMaxEdge (1440) — asserted by value so this test doesn't
      // depend on importing the detail-provider constant.
      expect(fake.previewMaxEdges, contains(1440));
    },
  );
}
