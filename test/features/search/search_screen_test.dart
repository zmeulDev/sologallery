import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sologallery/core/database/app_database.dart' show AppDatabase;
import 'package:sologallery/core/database/daos/index_dao.dart'
    show FavoriteAsset;
import 'package:sologallery/core/database/daos/albums_dao.dart'
    show AlbumSummary;
import 'package:sologallery/core/database/daos/faces_dao.dart'
    show PersonSummary;
import 'package:sologallery/core/database/database_provider.dart';
import 'package:sologallery/core/theme/app_theme.dart';
import 'package:sologallery/features/albums/albums_providers.dart';
import 'package:sologallery/features/people/people_providers.dart';
import 'package:sologallery/features/saved/saved_providers.dart';
import 'package:sologallery/features/search/search_providers.dart';
import 'package:sologallery/features/search/search_screen.dart';
import 'package:sologallery/features/search/widgets/recently_viewed_row.dart';
import 'package:sologallery/features/settings/consent_provider.dart';
import 'package:sologallery/services/indexing_service.dart';
import 'package:sologallery/services/permission_provider.dart';
import 'package:sologallery/services/photo_library_service.dart';
import 'package:sologallery/widgets/asset_thumbnail.dart';

import '../../support/asset_fixtures.dart';
import '../../support/fake_photo_library_service.dart';

class _ActiveSearchTabNotifier extends SearchTabActiveNotifier {
  @override
  bool build() => true;
}

void main() {
  Future<void> pump(
    WidgetTester tester, {
    List<AssetRef> assets = const [],
    List<AlbumSummary> albums = const [],
    List<FavoriteAsset> favorites = const [],
    List<DeviceFolder> folders = const [],
    bool searchEnabled = false,
    List<String> browseLabels = const [],
    List<String> recentlyViewed = const [],
    List<PersonSummary> people = const [],
    bool searchTabActive = false,
    IndexingStatus indexing = const IndexingStatus.idle(),
  }) async {
    final fake = FakePhotoLibraryService(assets: assets, folders: folders);
    // Content search reads the DB; give it an empty in-memory one.
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final router = GoRouter(
      initialLocation: '/search',
      routes: [
        GoRoute(path: '/search', builder: (_, _) => const SearchScreen()),
        GoRoute(
          path: '/album/:id',
          builder: (_, _) => const Scaffold(body: Text('album-detail')),
        ),
        GoRoute(
          path: '/folder',
          builder: (_, state) => Scaffold(
            body: Text('folder-detail:${state.uri.queryParameters['id']}'),
          ),
        ),
        GoRoute(
          path: '/photo/:id',
          builder: (_, state) => Scaffold(
            body: Text('photo-detail:${state.pathParameters['id']}'),
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          photoLibraryServiceProvider.overrideWithValue(fake),
          databaseProvider.overrideWithValue(db),
          albumSummariesProvider.overrideWith((ref) => Stream.value(albums)),
          savedFavoritesProvider.overrideWith((ref) => Stream.value(favorites)),
          searchEnabledProvider.overrideWith(
            (ref) => Stream.value(searchEnabled),
          ),
          indexingStatusProvider.overrideWith((ref) => Stream.value(indexing)),
          // The chip row is DB-derived (top labels by count); the ranking
          // itself is covered by the DAO and provider tests.
          topBrowseLabelsProvider.overrideWith(
            (ref) => Stream.value(browseLabels),
          ),
          recentlyViewedProvider.overrideWith(
            (ref, limit) => Stream.value(recentlyViewed),
          ),
          personSummariesProvider.overrideWith(
            (ref) => Stream.value(people),
          ),
          searchTabActiveProvider.overrideWith(
            () => searchTabActive
                ? _ActiveSearchTabNotifier()
                : SearchTabActiveNotifier(),
          ),
        ],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    // Bounded pumps only — a focused TextField's cursor blink never settles.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  /// Enters [text] and pumps past the 280 ms debounce plus the async result.
  Future<void> type(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  /// Dispose the tree and elapse time so the debounce / cursor-blink timers
  /// don't trip the pending-timer teardown invariant (CLAUDE.md gotcha).
  Future<void> settle(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  // The indexing note used to live here, so an indexing library said it twice
  // once the shell took it over. Search owns search; the shell owns the strip.
  testWidgets('leaves the indexing message to the shell', (tester) async {
    await pump(
      tester,
      indexing: const IndexingStatus(remaining: 12, total: 40),
    );
    expect(find.textContaining('indexing'), findsNothing);
    expect(find.textContaining('Analyzing'), findsNothing);
    await settle(tester);
  });

  testWidgets('shows the idle hint before any input', (tester) async {
    await pump(tester);
    expect(find.textContaining('Search your library by date'), findsOneWidget);
    await settle(tester);
  });

  // The floating nav capsule reaches the screen as a bottom inset; the browse
  // list has to pad by it or its last row hides behind the capsule. See
  // lib/widgets/nav_pill_bar.dart.
  testWidgets('the browse list clears the nav capsule', (tester) async {
    tester.view.padding = const FakeViewPadding(bottom: 96);
    addTearDown(tester.view.reset);
    final inset = 96 / tester.view.devicePixelRatio;

    await pump(tester);

    final padded = tester.widgetList<ListView>(find.byType(ListView)).where(
          (l) => l.padding?.resolve(TextDirection.ltr).bottom == inset,
        );
    expect(padded, hasLength(1),
        reason: 'The browse list should carry the bottom inset.');
    await settle(tester);
  });

  testWidgets('the facet pills are visible on the idle screen', (tester) async {
    // Showing the pills before typing makes the narrowing controls discoverable
    // and keeps the same field/facet anatomy once the user commits a query.
    await pump(tester);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Videos'), findsOneWidget);
    expect(find.text('Favorites'), findsOneWidget);
    await settle(tester);
  });

  testWidgets('the facet pills arrive with the results', (tester) async {
    await pump(tester, assets: assetsInMonth(2026, 8, 2));
    await type(tester, '2026-08');
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Videos'), findsOneWidget);
    expect(find.text('Favorites'), findsOneWidget);
    await settle(tester);
  });

  testWidgets('the title and subtitle sit above the search field on idle', (
    tester,
  ) async {
    // The idle screen keeps a compact subtitle plus the app-bar title; both sit
    // above the anchored search field.
    await pump(tester);

    final titleTop = tester.getTopLeft(find.text('Search')).dy;
    final subtitleTop =
        tester.getTopLeft(find.textContaining('Find photos, dates')).dy;
    final fieldTop = tester.getTopLeft(find.byType(TextField)).dy;
    expect(titleTop, lessThan(subtitleTop),
        reason: 'The app-bar title should be the topmost header.');
    expect(subtitleTop, lessThan(fieldTop),
        reason: 'The subtitle should precede the search field.');
    await settle(tester);
  });

  testWidgets('idle sections stack in the requested order', (tester) async {
    await pump(
      tester,
      searchEnabled: true,
      browseLabels: const ['Dog', 'Cat'],
      people: const [
        PersonSummary(
          id: 1,
          displayName: 'Alice',
          coverAssetId: null,
          faceCount: 3,
        ),
      ],
      recentlyViewed: const ['recent-1'],
    );

    final pillsTop = tester.getTopLeft(find.text('All')).dy;
    final fieldTop = tester.getTopLeft(find.byType(TextField)).dy;
    final labelsTop = tester.getTopLeft(find.text('ON-DEVICE LABELS')).dy;
    final peopleTop = tester.getTopLeft(find.text('PEOPLE')).dy;
    final recentTop = tester.getTopLeft(find.text('RECENTLY VIEWED')).dy;

    expect(pillsTop, lessThan(fieldTop),
        reason: 'Facet pills should sit above the search field.');
    expect(fieldTop, lessThan(labelsTop),
        reason: 'The search field should sit above On-device labels.');
    expect(labelsTop, lessThan(peopleTop),
        reason: 'On-device labels should sit above People.');
    expect(peopleTop, lessThan(recentTop),
        reason: 'People should sit above Recently viewed.');
    await settle(tester);
  });

  testWidgets(
    'the search field is not the first focusable node and stays unfocused',
    (tester) async {
      // Simulate Search becoming the active branch; the field must not steal
      // focus and pop the keyboard.
      await pump(tester, searchTabActive: true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.focusNode, isNotNull);
      expect(field.focusNode!.hasFocus, isFalse);
      await settle(tester);
    },
  );

  testWidgets('the recently viewed carousel renders thumbnails when it has ids', (
    tester,
  ) async {
    await pump(tester, recentlyViewed: const ['recent-1', 'recent-2']);

    // SectionHeader renders the label uppercase.
    expect(find.text('RECENTLY VIEWED'), findsOneWidget);
    expect(find.byType(AssetThumbnail), findsNWidgets(2));
    await settle(tester);
  });

  testWidgets('the recently viewed carousel hides when it is empty', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('RECENTLY VIEWED'), findsNothing);
    await settle(tester);
  });

  // Once a query is running the screen shows results only — the recency
  // carousel is an idle-state entry point, not a result.
  testWidgets('the recently viewed carousel hides once a query is active', (
    tester,
  ) async {
    await pump(tester, recentlyViewed: const ['recent-1', 'recent-2']);
    expect(find.text('RECENTLY VIEWED'), findsOneWidget);

    await type(tester, 'june 2026');

    expect(find.text('RECENTLY VIEWED'), findsNothing);
    expect(find.byType(RecentlyViewedRow), findsNothing);
    await settle(tester);
  });

  testWidgets('the recently viewed carousel is a two-row horizontal grid', (
    tester,
  ) async {
    await pump(tester, recentlyViewed: const [
      'recent-1',
      'recent-2',
      'recent-3',
      'recent-4',
    ]);

    final gridFinder = find.descendant(
      of: find.byType(RecentlyViewedRow),
      matching: find.byType(GridView),
    );
    expect(gridFinder, findsOneWidget);

    final grid = tester.widget<GridView>(gridFinder);
    expect(grid.scrollDirection, Axis.horizontal,
        reason: 'Recently viewed should scroll horizontally.');

    final delegate = grid.gridDelegate
        as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, 2,
        reason: 'Recently viewed should render two rows.');
    await settle(tester);
  });

  testWidgets('tapping a recent thumbnail opens its detail view', (tester) async {
    await pump(tester, recentlyViewed: const ['recent-1']);

    await tester.tap(find.byType(AssetThumbnail));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('photo-detail:recent-1'), findsOneWidget);
    await settle(tester);
  });

  testWidgets('a date query shows the Photos section with results', (
    tester,
  ) async {
    await pump(tester, assets: assetsInMonth(2026, 8, 4));
    await type(tester, '2026-08');

    expect(find.text('PHOTOS'), findsOneWidget);
    expect(find.byType(AssetThumbnail), findsWidgets);
    await settle(tester);
  });

  testWidgets('a matching album name shows the Albums section', (tester) async {
    await pump(
      tester,
      albums: const [
        AlbumSummary(
          id: 7,
          name: 'Iceland 2026',
          entryCount: 12,
          coverAssetId: null,
        ),
      ],
    );
    await type(tester, 'ice');

    expect(find.text('ALBUMS'), findsOneWidget);
    expect(find.text('Iceland 2026'), findsOneWidget);
    await settle(tester);
  });

  testWidgets('tapping an album row navigates to its detail', (tester) async {
    await pump(
      tester,
      albums: const [
        AlbumSummary(
          id: 7,
          name: 'Iceland 2026',
          entryCount: 12,
          coverAssetId: null,
        ),
      ],
    );
    await type(tester, 'iceland');

    await tester.tap(find.text('Iceland 2026'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('album-detail'), findsOneWidget);
    await settle(tester);
  });

  testWidgets('the People strip appears on idle when people exist', (
    tester,
  ) async {
    await pump(
      tester,
      people: const [
        PersonSummary(
          id: 1,
          displayName: 'Alice',
          coverAssetId: null,
          faceCount: 3,
        ),
      ],
    );

    expect(find.text('PEOPLE'), findsOneWidget);
    expect(find.text('Alice'), findsOneWidget);
    await settle(tester);
  });

  testWidgets('person-name matching shows a People section in results', (
    tester,
  ) async {
    await pump(
      tester,
      people: const [
        PersonSummary(
          id: 1,
          displayName: 'Alice',
          coverAssetId: null,
          faceCount: 3,
        ),
        PersonSummary(
          id: 2,
          displayName: 'Bob',
          coverAssetId: null,
          faceCount: 5,
        ),
      ],
    );
    await type(tester, 'ali');

    expect(find.text('PEOPLE'), findsOneWidget);
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Bob'), findsNothing);
    await settle(tester);
  });

  testWidgets('the People strip sits above the search field in results', (
    tester,
  ) async {
    await pump(
      tester,
      people: const [
        PersonSummary(
          id: 1,
          displayName: 'Alice',
          coverAssetId: null,
          faceCount: 3,
        ),
      ],
    );
    await type(tester, 'ali');

    final peopleTop = tester.getTopLeft(find.text('PEOPLE')).dy;
    final fieldTop = tester.getTopLeft(find.byType(TextField)).dy;
    expect(peopleTop, lessThan(fieldTop),
        reason: 'People should sit above the search field in results.');
    await settle(tester);
  });

  testWidgets('results are the only thing below the field once a query runs', (
    tester,
  ) async {
    await pump(
      tester,
      assets: assetsInMonth(2026, 8, 2),
      recentlyViewed: const ['recent-1'],
    );
    await type(tester, '2026-08');

    expect(find.text('PHOTOS'), findsOneWidget);
    expect(find.text('RECENTLY VIEWED'), findsNothing);
    await settle(tester);
  });

  testWidgets('device folders do not appear on Search', (tester) async {
    // Folders are collections you browse, not a way to narrow a query — they
    // live on the Albums tab, which already gathers every collection.
    await pump(
      tester,
      folders: const [DeviceFolder(id: 'cam', name: 'Camera', count: 1204)],
    );
    expect(find.text('FOLDERS'), findsNothing);
    expect(find.text('DEVICE FOLDERS'), findsNothing);
    expect(find.text('Camera'), findsNothing);
    await settle(tester);
  });

  testWidgets('the clear button appears after typing and resets to idle', (
    tester,
  ) async {
    await pump(tester, assets: assetsInMonth(2026, 8, 2));
    expect(find.byIcon(Icons.close_rounded), findsNothing);

    await type(tester, '2026');
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.textContaining('Search your library by date'), findsOneWidget);
    await settle(tester);
  });

  testWidgets('the results header shows the loaded count', (tester) async {
    await pump(tester, assets: assetsInMonth(2026, 8, 4));
    await type(tester, '2026-08');

    expect(find.text('PHOTOS'), findsOneWidget);
    expect(find.text('4 results'), findsOneWidget);
    await settle(tester);
  });

  testWidgets('browse-label chips appear only when content search is on', (
    tester,
  ) async {
    // Off: no browse section → the idle prompt stands alone.
    await pump(tester, browseLabels: const ['Dog']);
    expect(find.text('ON-DEVICE LABELS'), findsNothing);
    await settle(tester);

    // On: this library's top labels render as tappable chips.
    await pump(tester, searchEnabled: true, browseLabels: const ['Dog', 'Cat']);
    expect(find.text('ON-DEVICE LABELS'), findsOneWidget);
    expect(find.text('Dog'), findsOneWidget);
    expect(find.text('Cat'), findsOneWidget);
    await settle(tester);
  });

  testWidgets('the chips keep the order they arrive in (most photos first)', (
    tester,
  ) async {
    await pump(
      tester,
      searchEnabled: true,
      browseLabels: const ['Dog', 'Cat', 'Beach'],
    );
    final xs = [
      for (final l in ['Dog', 'Cat', 'Beach'])
        tester.getTopLeft(find.text(l)).dx,
    ];
    expect(xs[0], lessThan(xs[1]));
    expect(xs[1], lessThan(xs[2]));
    await settle(tester);
  });

  testWidgets('the label section is hidden while nothing is labeled yet', (
    tester,
  ) async {
    // Fresh library or an indexer still working: chips that match no photo
    // would be worse than none, so the idle prompt carries the screen.
    await pump(tester, searchEnabled: true);
    expect(find.text('ON-DEVICE LABELS'), findsNothing);
    expect(
      find.textContaining('Search your library by what is in a photo'),
      findsOneWidget,
    );
    await settle(tester);
  });

  testWidgets('tapping a label chip runs a content search', (tester) async {
    await pump(tester, searchEnabled: true, browseLabels: const ['Beach']);
    expect(find.text('Beach'), findsOneWidget);

    await tester.tap(find.text('Beach'));
    await tester.pump(); // commit (no debounce for a chip)
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // The chip mirrors into the field and routes through content search; the
    // empty in-memory DB has no labels, so the search reports no matches.
    expect(find.text('Beach'), findsOneWidget); // now the field's value
    expect(find.text('No matches.'), findsOneWidget);
    await settle(tester);
  });

  testWidgets('a query set on the provider restores into the field', (
    tester,
  ) async {
    // Simulates returning to Search with a live query (a branch rebuild, or a
    // chip set while the tab was away): the field must restore from the
    // provider in initState, not come up blank.
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        photoLibraryServiceProvider.overrideWithValue(
          FakePhotoLibraryService(),
        ),
        albumSummariesProvider.overrideWith((ref) => Stream.value(const [])),
        savedFavoritesProvider.overrideWith((ref) => Stream.value(const [])),
        searchEnabledProvider.overrideWith((ref) => Stream.value(false)),
        indexingStatusProvider.overrideWith(
          (ref) => Stream.value(const IndexingStatus.idle()),
        ),
      ],
    );
    addTearDown(container.dispose);
    // Keep the autoDispose query alive and seed it before the screen mounts.
    container.listen(searchQueryProvider, (_, _) {});
    container.read(searchQueryProvider.notifier).set('mountains');

    final router = GoRouter(
      initialLocation: '/search',
      routes: [
        GoRoute(path: '/search', builder: (_, _) => const SearchScreen()),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('mountains'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
