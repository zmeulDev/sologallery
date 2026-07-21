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
import 'package:sologallery/core/database/database_provider.dart';
import 'package:sologallery/core/theme/app_theme.dart';
import 'package:sologallery/features/albums/albums_providers.dart';
import 'package:sologallery/features/saved/saved_providers.dart';
import 'package:sologallery/features/search/search_providers.dart';
import 'package:sologallery/features/search/search_screen.dart';
import 'package:sologallery/features/settings/consent_provider.dart';
import 'package:sologallery/services/indexing_service.dart';
import 'package:sologallery/services/permission_provider.dart';
import 'package:sologallery/services/photo_library_service.dart';
import 'package:sologallery/widgets/asset_thumbnail.dart';

import '../../support/asset_fixtures.dart';
import '../../support/fake_photo_library_service.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    List<AssetRef> assets = const [],
    List<AlbumSummary> albums = const [],
    List<FavoriteAsset> favorites = const [],
    List<DeviceFolder> folders = const [],
    bool searchEnabled = false,
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
          indexingStatusProvider.overrideWith(
            (ref) => Stream.value(const IndexingStatus.idle()),
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

  testWidgets('shows the idle hint before any input', (tester) async {
    await pump(tester);
    expect(find.textContaining('Search your library by date'), findsOneWidget);
    await settle(tester);
  });

  testWidgets('the facet pills stay out of the idle screen', (tester) async {
    // Idle, they would be four controls narrowing nothing, competing with the
    // browse entry points that are the actual invitation.
    await pump(tester);
    expect(find.text('Videos'), findsNothing);
    expect(find.text('Favorites'), findsNothing);
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

  testWidgets('states plainly that search is local', (tester) async {
    await pump(tester);
    expect(
      find.textContaining('Search runs entirely on this device'),
      findsOneWidget,
    );
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
    await pump(tester);
    expect(find.text('ON-DEVICE LABELS'), findsNothing);
    await settle(tester);

    // On: the curated allowlist renders as tappable chips.
    await pump(tester, searchEnabled: true);
    expect(find.text('ON-DEVICE LABELS'), findsOneWidget);
    expect(find.text('Beach'), findsOneWidget);
    await settle(tester);
  });

  testWidgets('tapping a label chip runs a content search', (tester) async {
    await pump(tester, searchEnabled: true);
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
