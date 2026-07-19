import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sologallery/core/theme/app_theme.dart';
import 'package:sologallery/features/library/domain/year_month.dart';
import 'package:sologallery/features/library/library_providers.dart';
import 'package:sologallery/features/library/library_screen.dart';
import 'package:sologallery/features/memories/memories_providers.dart';
import 'package:sologallery/services/indexing_service.dart';
import 'package:sologallery/services/permission_provider.dart';
import 'package:sologallery/services/photo_library_service.dart';
import 'package:sologallery/widgets/asset_thumbnail.dart';
import 'package:sologallery/widgets/limited_access_banner.dart';

import '../../support/asset_fixtures.dart';
import '../../support/fake_photo_library_service.dart';

void main() {
  /// Renders [LibraryScreen] with the library providers overridden to fixed
  /// values — the DB-backed provider logic is covered in library_providers_test;
  /// here we assert the screen's structure given month counts / previews. The
  /// cache is marked ready so the empty/data branches (not the spinner) show.
  Future<void> pump(
    WidgetTester tester, {
    required PhotoAccess access,
    List<AssetRef> assets = const [],
    List<AssetRef> undatedAssets = const [],
    bool cacheReady = true,
    bool settle = true,
  }) async {
    final byMonth = <YearMonth, List<AssetRef>>{};
    for (final a in assets) {
      (byMonth[YearMonth.fromDate(a.createdAt)] ??= []).add(a);
    }
    final counts = [
      for (final month in byMonth.keys.toList()
        ..sort((a, b) => b.compareTo(a)))
        (month: month, count: byMonth[month]!.length),
    ];

    final fake = FakePhotoLibraryService(access: access);
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
        GoRoute(
          path: '/settings',
          builder: (_, _) => const Scaffold(body: Text('settings')),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          photoLibraryServiceProvider.overrideWithValue(fake),
          libraryCacheReadyProvider.overrideWithValue(AsyncData(cacheReady)),
          // The carousel would otherwise reach the real database through
          // memoriesDaoProvider; the carousel has its own test file.
          memoriesProvider.overrideWithValue(const AsyncData([])),
          libraryMonthCountsProvider.overrideWithValue(AsyncData(counts)),
          monthPreviewsProvider.overrideWith(
            (ref, month) => Stream.value([
              for (final a in byMonth[month] ?? const <AssetRef>[]) a.id,
            ].take(6).toList()),
          ),
          olderCountProvider.overrideWithValue(AsyncData(undatedAssets.length)),
          olderPreviewsProvider.overrideWith(
            (ref) => Stream.value([for (final a in undatedAssets.take(6)) a.id]),
          ),
        ],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    // A CircularProgressIndicator never lets pumpAndSettle settle, so the
    // not-ready (spinner) case uses bounded pumps instead.
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('empty library shows the empty state', (tester) async {
    await pump(tester, access: PhotoAccess.granted);
    expect(find.text('No photos yet'), findsOneWidget);
  });

  testWidgets('spinner while the cache is not yet ready', (tester) async {
    await pump(tester, access: PhotoAccess.granted, cacheReady: false, settle: false);
    expect(find.text('No photos yet'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
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

  testWidgets('tapping the app-bar gear opens Settings', (tester) async {
    await pump(tester, access: PhotoAccess.granted);

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(find.text('settings'), findsOneWidget);
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
