import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sologallery/core/theme/app_theme.dart';
import 'package:sologallery/features/library/library_screen.dart';
import 'package:sologallery/services/permission_provider.dart';
import 'package:sologallery/services/photo_library_service.dart';
import 'package:sologallery/widgets/asset_thumbnail.dart';
import 'package:sologallery/widgets/limited_access_banner.dart';

import '../../support/asset_fixtures.dart';
import '../../support/fake_photo_library_service.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required PhotoAccess access,
    List<AssetRef> assets = const [],
    List<AssetRef> undatedAssets = const [],
  }) async {
    final fake = FakePhotoLibraryService(
      access: access,
      assets: assets,
      undatedAssets: undatedAssets,
    );
    // A minimal router so the "View all" push targets resolve.
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const LibraryScreen()),
        GoRoute(
          path: '/month/:key',
          builder: (_, _) => const Scaffold(body: Text('month')),
        ),
        GoRoute(
          path: '/older',
          builder: (_, _) => const Scaffold(body: Text('older-grid')),
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

  testWidgets('empty library shows the empty state', (tester) async {
    await pump(tester, access: PhotoAccess.granted);
    expect(find.text('No photos yet'), findsOneWidget);
  });

  testWidgets('renders a month section with header, previews and count',
      (tester) async {
    await pump(
      tester,
      access: PhotoAccess.granted,
      assets: assetsInMonth(2026, 8, 7),
    );

    expect(find.text('AUGUST 2026'), findsOneWidget);
    expect(find.text('View all 7'), findsOneWidget);
    // Preview is capped at six thumbnails.
    expect(find.byType(AssetThumbnail), findsNWidgets(6));
  });

  testWidgets('tapping View all navigates to the month route', (tester) async {
    await pump(
      tester,
      access: PhotoAccess.granted,
      assets: assetsInMonth(2026, 8, 7),
    );

    await tester.tap(find.text('View all 7'));
    await tester.pumpAndSettle();
    expect(find.text('month'), findsOneWidget);
  });

  testWidgets('undated photos render a trailing Older section', (tester) async {
    await pump(
      tester,
      access: PhotoAccess.granted,
      assets: assetsInMonth(2026, 8, 3),
      undatedAssets: assetsInMonth(2020, 1, 4),
    );

    expect(find.text('AUGUST 2026'), findsOneWidget);
    expect(find.text('OLDER'), findsOneWidget);
    expect(find.text('View all 4'), findsOneWidget);
  });

  testWidgets('no Older section when there are no undated photos',
      (tester) async {
    await pump(
      tester,
      access: PhotoAccess.granted,
      assets: assetsInMonth(2026, 8, 3),
    );
    expect(find.text('OLDER'), findsNothing);
  });

  testWidgets('tapping Older View all navigates to /older', (tester) async {
    await pump(
      tester,
      access: PhotoAccess.granted,
      assets: assetsInMonth(2026, 8, 3),
      undatedAssets: assetsInMonth(2020, 1, 4),
    );

    await tester.tap(find.text('View all 4'));
    await tester.pumpAndSettle();
    expect(find.text('older-grid'), findsOneWidget);
  });

  testWidgets('limited access shows the banner', (tester) async {
    await pump(
      tester,
      access: PhotoAccess.limited,
      assets: assetsInMonth(2026, 8, 2),
    );
    expect(find.byType(LimitedAccessBanner), findsOneWidget);
  });

  testWidgets('full access hides the banner', (tester) async {
    await pump(
      tester,
      access: PhotoAccess.granted,
      assets: assetsInMonth(2026, 8, 2),
    );
    expect(find.byType(LimitedAccessBanner), findsNothing);
  });
}
