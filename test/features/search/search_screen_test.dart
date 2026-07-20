import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sologallery/core/database/app_database.dart' show AppDatabase, Favorite;
import 'package:sologallery/core/database/daos/albums_dao.dart' show AlbumSummary;
import 'package:sologallery/core/database/database_provider.dart';
import 'package:sologallery/core/theme/app_theme.dart';
import 'package:sologallery/features/albums/albums_providers.dart';
import 'package:sologallery/features/saved/saved_providers.dart';
import 'package:sologallery/features/search/search_screen.dart';
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
    List<Favorite> favorites = const [],
    List<DeviceFolder> folders = const [],
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
    expect(
      find.textContaining('Search your library by date'),
      findsOneWidget,
    );
    await settle(tester);
  });

  testWidgets('renders the facet pills', (tester) async {
    await pump(tester);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Photos'), findsOneWidget);
    expect(find.text('Videos'), findsOneWidget);
    expect(find.text('Favorites'), findsOneWidget);
    await settle(tester);
  });

  testWidgets('a date query shows the Photos section with results',
      (tester) async {
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

  testWidgets('the idle state lists device folders with their photo counts',
      (tester) async {
    await pump(
      tester,
      folders: const [
        DeviceFolder(id: 'cam', name: 'Camera', count: 1204),
        DeviceFolder(id: 'shots', name: 'Screenshots', count: 318),
        DeviceFolder(id: 'one', name: 'Scans', count: 1),
      ],
    );

    expect(find.text('FOLDERS'), findsOneWidget);
    expect(find.text('Camera'), findsOneWidget);
    expect(find.text('1204 photos'), findsOneWidget);
    expect(find.text('318 photos'), findsOneWidget);
    expect(find.text('1 photo'), findsOneWidget); // singular, not "1 photos"
    // Browsing replaces the prompt once there's something to browse.
    expect(find.textContaining('Search your library by date'), findsNothing);
    await settle(tester);
  });

  testWidgets('tapping a folder opens its detail grid', (tester) async {
    await pump(
      tester,
      folders: const [DeviceFolder(id: 'cam', name: 'Camera', count: 12)],
    );

    await tester.tap(find.text('Camera'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('folder-detail:cam'), findsOneWidget);
    await settle(tester);
  });

  testWidgets('a folder id needing escaping still routes correctly',
      (tester) async {
    // iOS folder ids are PHAssetCollection local identifiers and contain "/",
    // which is why the route carries them as a query parameter.
    await pump(
      tester,
      folders: const [
        DeviceFolder(id: 'ABC123/L0/040', name: 'Recents', count: 5),
      ],
    );

    await tester.tap(find.text('Recents'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('folder-detail:ABC123/L0/040'), findsOneWidget);
    await settle(tester);
  });

  testWidgets('the clear button appears after typing and resets to idle',
      (tester) async {
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
}
