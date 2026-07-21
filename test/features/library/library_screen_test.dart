import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sologallery/core/theme/app_theme.dart';
import 'package:sologallery/features/library/domain/library_filter.dart';
import 'package:sologallery/features/library/domain/year_month.dart';
import 'package:sologallery/features/library/library_providers.dart';
import 'package:sologallery/features/library/library_screen.dart';
import 'package:sologallery/features/library/widgets/year_header.dart';
import 'package:sologallery/features/memories/memories_providers.dart';
import 'package:sologallery/features/memories/widgets/memories_carousel.dart';
import 'package:sologallery/widgets/asset_grid.dart';
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
    List<AssetRef> weekAssets = const [],
    bool cacheReady = true,
    bool settle = true,
  }) async {
    final byMonth = <YearMonth, List<AssetRef>>{};
    for (final a in assets) {
      (byMonth[YearMonth.fromDate(a.createdAt)] ??= []).add(a);
    }
    final counts = [
      for (final month in byMonth.keys.toList()..sort((a, b) => b.compareTo(a)))
        (month: month, count: byMonth[month]!.length),
    ];

    // The year axis is derived from the same fixture assets, so the two
    // groupings can't disagree the way a hand-written second fixture would.
    final byYear = <int, List<AssetRef>>{};
    for (final a in assets) {
      (byYear[a.createdAt.year] ??= []).add(a);
    }
    final yearCounts = [
      for (final year in byYear.keys.toList()..sort((a, b) => b.compareTo(a)))
        (year: year, count: byYear[year]!.length),
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
            (ref, month) => Stream.value(
              [
                for (final a in byMonth[month] ?? const <AssetRef>[]) a.id,
              ].take(6).toList(),
            ),
          ),
          olderCountProvider.overrideWithValue(AsyncData(undatedAssets.length)),
          olderPreviewsProvider.overrideWith(
            (ref) =>
                Stream.value([for (final a in undatedAssets.take(6)) a.id]),
          ),
          libraryYearCountsProvider.overrideWithValue(AsyncData(yearCounts)),
          yearPreviewsProvider.overrideWith(
            (ref, year) => Stream.value(
              [
                for (final a in byYear[year] ?? const <AssetRef>[]) a.id,
              ].take(6).toList(),
            ),
          ),
          thisWeekAssetsProvider.overrideWithValue(AsyncData(weekAssets)),
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
    await pump(
      tester,
      access: PhotoAccess.granted,
      cacheReady: false,
      settle: false,
    );
    expect(find.text('No photos yet'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('renders a month section with header, previews and count', (
    tester,
  ) async {
    await pump(
      tester,
      access: PhotoAccess.granted,
      assets: assetsInMonth(2026, 8, 7),
    );

    expect(find.text('AUGUST 2026'), findsOneWidget);
    // A quiet tally, not a button: "items" because a month mixes stills and
    // video, and the grid below shows both.
    expect(find.text('7 items'), findsOneWidget);
    // Preview is capped at six thumbnails.
    expect(find.byType(AssetThumbnail), findsNWidgets(6));
  });

  // The floating nav capsule reaches the screen as a bottom inset; the timeline
  // has to pad by it or its last month section hides behind the capsule. See
  // lib/widgets/nav_pill_bar.dart.
  testWidgets('the timeline clears the nav capsule', (tester) async {
    tester.view.padding = const FakeViewPadding(bottom: 96);
    addTearDown(tester.view.reset);
    final inset = 96 / tester.view.devicePixelRatio;

    await pump(
      tester,
      access: PhotoAccess.granted,
      assets: assetsInMonth(2026, 8, 7),
    );

    final timeline = tester.widget<ListView>(find.byType(ListView).first);
    expect(
      timeline.padding?.resolve(TextDirection.ltr).bottom,
      AppSpace.s24 + inset,
    );
  });

  testWidgets('tapping the section header navigates to the month route', (
    tester,
  ) async {
    await pump(
      tester,
      access: PhotoAccess.granted,
      assets: assetsInMonth(2026, 8, 7),
    );

    // The whole header row is the target — the label included, not just a
    // trailing control.
    await tester.tap(find.text('AUGUST 2026'));
    await tester.pumpAndSettle();
    expect(find.text('month'), findsOneWidget);
  });

  testWidgets('a one-item section reads in the singular', (tester) async {
    await pump(
      tester,
      access: PhotoAccess.granted,
      assets: assetsInMonth(2026, 8, 1),
    );
    expect(find.text('1 item'), findsOneWidget);
  });

  testWidgets('tapping the app-bar gear opens Settings', (tester) async {
    await pump(tester, access: PhotoAccess.granted);

    await tester.tap(find.byIcon(Icons.settings_rounded));
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
    expect(find.text('4 items'), findsOneWidget);
  });

  testWidgets('no Older section when there are no undated photos', (
    tester,
  ) async {
    await pump(
      tester,
      access: PhotoAccess.granted,
      assets: assetsInMonth(2026, 8, 3),
    );
    expect(find.text('OLDER'), findsNothing);
  });

  testWidgets('tapping the Older header navigates to /older', (tester) async {
    await pump(
      tester,
      access: PhotoAccess.granted,
      assets: assetsInMonth(2026, 8, 3),
      undatedAssets: assetsInMonth(2020, 1, 4),
    );

    await tester.tap(find.text('OLDER'));
    await tester.pumpAndSettle();
    expect(find.text('older-grid'), findsOneWidget);
  });

  group('time filters', () {
    /// Two years of fixture assets, so year grouping has something to group.
    List<AssetRef> twoYears() => [
      ...assetsInMonth(2026, 8, 3),
      ...assetsInMonth(2026, 2, 2),
      ...assetsInMonth(2025, 11, 4),
    ];

    Future<void> selectFilter(WidgetTester tester, LibraryFilter f) async {
      await tester.tap(find.text(f.label));
      await tester.pumpAndSettle();
    }

    testWidgets('the bar offers every filter, All active by default', (
      tester,
    ) async {
      await pump(tester, access: PhotoAccess.granted, assets: twoYears());

      for (final f in LibraryFilter.values) {
        expect(find.text(f.label), findsOneWidget, reason: f.name);
      }
      // All is the default, so the month sections and the carousel are up.
      expect(find.text('AUGUST 2026'), findsOneWidget);
      expect(find.byType(MemoriesCarousel), findsOneWidget);
    });

    testWidgets('All shows no year heroes', (tester) async {
      await pump(tester, access: PhotoAccess.granted, assets: twoYears());
      expect(find.byType(YearHeader), findsNothing);
    });

    testWidgets('Months keeps the month sections and adds a hero per year', (
      tester,
    ) async {
      await pump(tester, access: PhotoAccess.granted, assets: twoYears());
      await selectFilter(tester, LibraryFilter.months);

      expect(find.text('AUGUST 2026'), findsOneWidget);
      expect(find.text('FEBRUARY 2026'), findsOneWidget);
      expect(find.text('NOVEMBER 2025'), findsOneWidget);
      // One hero per year, not per month.
      expect(find.byType(YearHeader), findsNWidgets(2));
      expect(find.text('2026'), findsOneWidget);
      expect(find.text('2025'), findsOneWidget);
      // The 2026 hero carries that year's total across both its months.
      expect(find.text('5 photos'), findsOneWidget);
    });

    testWidgets('the time filters drop the memories carousel', (tester) async {
      await pump(tester, access: PhotoAccess.granted, assets: twoYears());
      for (final f in [
        LibraryFilter.months,
        LibraryFilter.year,
        LibraryFilter.thisWeek,
      ]) {
        await selectFilter(tester, f);
        expect(find.byType(MemoriesCarousel), findsNothing, reason: f.name);
      }
    });

    testWidgets('Year collapses to one section per year', (tester) async {
      await pump(tester, access: PhotoAccess.granted, assets: twoYears());
      await selectFilter(tester, LibraryFilter.year);

      expect(find.byType(YearHeader), findsNWidgets(2));
      expect(find.text('5 photos'), findsOneWidget); // 2026
      expect(find.text('4 photos'), findsOneWidget); // 2025
      // The month axis is gone entirely.
      expect(find.text('AUGUST 2026'), findsNothing);
      expect(find.text('FEBRUARY 2026'), findsNothing);
    });

    testWidgets('This week shows the window as one flat grid', (tester) async {
      await pump(
        tester,
        access: PhotoAccess.granted,
        assets: twoYears(),
        weekAssets: assetsInMonth(2026, 8, 4),
      );
      await selectFilter(tester, LibraryFilter.thisWeek);

      expect(find.byType(AssetGrid), findsOneWidget);
      // No sections — a week doesn't need dividing.
      expect(find.text('AUGUST 2026'), findsNothing);
      expect(find.byType(YearHeader), findsNothing);
    });

    testWidgets('an empty week says so, and says over what window', (
      tester,
    ) async {
      await pump(tester, access: PhotoAccess.granted, assets: twoYears());
      await selectFilter(tester, LibraryFilter.thisWeek);

      expect(find.text('No photos in the last 7 days.'), findsOneWidget);
      expect(find.byType(AssetGrid), findsNothing);
    });

    testWidgets('switching back to All restores the full timeline', (
      tester,
    ) async {
      await pump(tester, access: PhotoAccess.granted, assets: twoYears());
      await selectFilter(tester, LibraryFilter.year);
      expect(find.text('AUGUST 2026'), findsNothing);

      await selectFilter(tester, LibraryFilter.all);
      expect(find.text('AUGUST 2026'), findsOneWidget);
      expect(find.byType(YearHeader), findsNothing);
      expect(find.byType(MemoriesCarousel), findsOneWidget);
    });

    testWidgets('the filter bar stays up on an empty library', (tester) async {
      await pump(tester, access: PhotoAccess.granted);
      // Otherwise the empty state is a dead end — there's no way back to a
      // filter that might have photos behind it.
      expect(find.text('No photos yet'), findsOneWidget);
      expect(find.text(LibraryFilter.year.label), findsOneWidget);
    });
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
