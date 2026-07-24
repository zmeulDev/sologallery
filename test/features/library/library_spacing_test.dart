import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sologallery/core/database/daos/memories_dao.dart'
    show MemorySummary;
import 'package:sologallery/core/theme/app_theme.dart';
import 'package:sologallery/features/library/domain/year_month.dart';
import 'package:sologallery/features/library/library_providers.dart';
import 'package:sologallery/features/library/library_screen.dart';
import 'package:sologallery/features/library/widgets/library_filter_bar.dart';
import 'package:sologallery/features/library/widgets/month_header.dart';
import 'package:sologallery/features/memories/memories_providers.dart';
import 'package:sologallery/features/memories/widgets/memories_carousel.dart';
import 'package:sologallery/services/indexing_service.dart';
import 'package:sologallery/services/permission_provider.dart';
import 'package:sologallery/services/photo_library_service.dart';
import 'package:sologallery/widgets/asset_thumbnail.dart';

import '../../support/asset_fixtures.dart';
import '../../support/fake_photo_library_service.dart';

/// The Library timeline's vertical rhythm, asserted as rendered geometry rather
/// than as padding constants — the reported bug was that the *visible* gap
/// between month sections was the sum of two paddings, which reading either
/// constant alone would not have caught.
void main() {
  const memories = [
    MemorySummary(
      id: 1,
      kind: 'onThisDay',
      title: 'On this day',
      subtitle: '2024',
      coverAssetId: 'cover-1',
      assetCount: 12,
    ),
  ];

  Future<void> pump(
    WidgetTester tester, {
    List<AssetRef> assets = const [],
    bool withMemories = false,
  }) async {
    // Two month sections plus a carousel are far taller than the default 800×600
    // surface, and the timeline builds lazily — on a short surface the second
    // month is never built and there is nothing to measure a gap to.
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final byMonth = <YearMonth, List<AssetRef>>{};
    for (final a in assets) {
      (byMonth[YearMonth.fromDate(a.createdAt)] ??= []).add(a);
    }
    final counts = [
      for (final month in byMonth.keys.toList()..sort((a, b) => b.compareTo(a)))
        (month: month, count: byMonth[month]!.length),
    ];

    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const LibraryScreen()),
        GoRoute(
          path: '/month/:key',
          builder: (_, _) => const Scaffold(body: Text('month')),
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
          photoLibraryServiceProvider.overrideWithValue(
            FakePhotoLibraryService(access: PhotoAccess.granted),
          ),
          libraryCacheReadyProvider.overrideWithValue(const AsyncData(true)),
          memoriesProvider.overrideWithValue(
            AsyncData(withMemories ? memories : const <MemorySummary>[]),
          ),
          libraryMonthCountsProvider.overrideWithValue(AsyncData(counts)),
          monthPreviewsProvider.overrideWith(
            (ref, month) => Stream.value([
              for (final a in byMonth[month] ?? const <AssetRef>[]) a.id,
            ].take(6).toList()),
          ),
          olderCountProvider.overrideWithValue(const AsyncData(0)),
          olderPreviewsProvider.overrideWith((ref) => Stream.value(const [])),
        ],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Vertical distance from the bottom of the widget at [a] to the top of the
  /// widget at [b] — the gap the user actually sees.
  double gapBetween(WidgetTester tester, Finder a, Finder b) =>
      tester.getRect(b).top - tester.getRect(a).bottom;

  /// The bottom edge of the *photos* in the first month section.
  ///
  /// Deliberately not the `GridView`'s own rect: a scroll view's box includes
  /// whatever padding it applied, so measuring from it hides a grid that
  /// silently absorbed the view inset — which is the bug this file exists for.
  /// Six previews in three columns means the last row is 3, 4, 5.
  Finder lastPreviewOfFirstSection() => find.byType(AssetThumbnail).at(5);

  testWidgets('consecutive month sections sit exactly one rhythm apart',
      (tester) async {
    await pump(
      tester,
      assets: [...assetsInMonth(2026, 8, 6), ...assetsInMonth(2026, 7, 6)],
    );

    final headers = find.byType(MonthHeader);
    expect(headers, findsNWidgets(2));

    // Last photo of the first section, then the header of the second: the gap
    // between them is the whole inter-section break. It used to be `s16 + s20`
    // because both edges paid for it.
    final gap = gapBetween(tester, lastPreviewOfFirstSection(), headers.at(1));
    expect(gap, AppSpace.s20);
  });

  // The gap survived the padding fix on device but not on host, because a
  // BoxScrollView with a null `padding` absorbs MediaQuery.padding on its main
  // axis (scroll_view.dart:901). Inside the shell that bottom inset is the
  // floating nav capsule, so each preview grid appended a capsule-sized band
  // under itself. The host view has no padding, so nothing showed it.
  testWidgets('a preview grid does not absorb the nav capsule inset', (
    tester,
  ) async {
    tester.view.padding = const FakeViewPadding(bottom: 96);
    addTearDown(tester.view.reset);

    await pump(
      tester,
      assets: [...assetsInMonth(2026, 8, 6), ...assetsInMonth(2026, 7, 6)],
    );

    final headers = find.byType(MonthHeader);
    final gap = gapBetween(tester, lastPreviewOfFirstSection(), headers.at(1));
    // Unchanged by the inset: the same rhythm as with no system padding.
    expect(gap, AppSpace.s20);
  });

  testWidgets('the memories break is twice the section rhythm', (tester) async {
    await pump(
      tester,
      assets: [...assetsInMonth(2026, 8, 6), ...assetsInMonth(2026, 7, 6)],
      withMemories: true,
    );

    final carousel = find.byType(MemoriesCarousel);
    expect(carousel, findsOneWidget);

    // Measure from the card row itself, not from the MemoriesCarousel widget —
    // the carousel's own break lives inside its render box, so its bottom edge
    // already includes it.
    final cardRow = find.descendant(
      of: carousel,
      matching: find.byType(ListView),
    );
    // The filter bar now rides between the carousel and the first month; the
    // break is split into two section-rhythm gaps (carousel → filter bar, and
    // filter bar → first month).
    final filterBar = find.byType(LibraryFilterBar);
    final monthHeaders = find.byType(MonthHeader, skipOffstage: false);
    final toFilterBar = gapBetween(tester, cardRow, filterBar);
    final toFirstMonth = gapBetween(tester, filterBar, monthHeaders.at(0));
    final betweenMonths =
        gapBetween(tester, lastPreviewOfFirstSection(), monthHeaders.at(1));

    // closeTo, not equals: the carousel's height is derived from a card
    // aspect ratio, so the rows land on fractional pixels.
    expect(betweenMonths, closeTo(AppSpace.s20, 0.01));
    expect(toFilterBar, closeTo(AppSpace.s20, 0.01));
    expect(toFirstMonth, closeTo(AppSpace.s20, 0.01));
  });

  testWidgets('with no memories the timeline keeps its own rhythm at the top',
      (tester) async {
    // The carousel renders nothing at all when empty, so its break must not
    // leave dead space above the first month. The filter bar then sits at the
    // top of the body, immediately above the first section.
    await pump(tester, assets: assetsInMonth(2026, 8, 6));

    // skipOffstage: false — a viewport reports a zero-extent child as offstage.
    final carousel = find.byType(MemoriesCarousel, skipOffstage: false);
    expect(tester.getSize(carousel).height, 0);
    expect(find.byType(LibraryFilterBar), findsOneWidget);
  });
}
