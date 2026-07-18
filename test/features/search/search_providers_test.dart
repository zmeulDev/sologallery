import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/core/database/app_database.dart' show AppDatabase, Favorite;
import 'package:sologallery/core/database/daos/albums_dao.dart' show AlbumSummary;
import 'package:sologallery/core/database/database_provider.dart';
import 'package:sologallery/features/albums/albums_providers.dart';
import 'package:sologallery/features/saved/saved_providers.dart';
import 'package:sologallery/features/search/domain/search_date.dart';
import 'package:sologallery/features/search/search_providers.dart';
import 'package:sologallery/services/permission_provider.dart';
import 'package:sologallery/services/photo_library_service.dart';

import '../../support/asset_fixtures.dart';
import '../../support/fake_photo_library_service.dart';

void main() {
  // Aug 2026 (3 assets, the first a video) + Jul 2026 (2 assets), newest first.
  List<AssetRef> library() => [
        ...assetsInMonth(2026, 8, 3),
        ...assetsInMonth(2026, 7, 2),
      ];

  ProviderContainer makeContainer({
    List<AssetRef>? assets,
    Map<String, Duration> videoDurations = const {},
    List<Favorite> favorites = const [],
    List<AlbumSummary> albums = const [],
  }) {
    final fake = FakePhotoLibraryService(
      assets: assets ?? library(),
      videoDurations: videoDurations,
    );
    final container = ProviderContainer(
      overrides: [
        photoLibraryServiceProvider.overrideWithValue(fake),
        savedFavoritesProvider.overrideWith((ref) => Stream.value(favorites)),
        albumSummariesProvider.overrideWith((ref) => Stream.value(albums)),
      ],
    );
    addTearDown(container.dispose);
    container.listen(searchAssetsProvider, (_, _) {});
    return container;
  }

  group('searchAssetsProvider', () {
    test('is empty when nothing is being searched on (idle guard)', () async {
      final container = makeContainer();
      expect(await container.read(searchAssetsProvider.future), isEmpty);
    });

    test('a month query windows results to that capture month', () async {
      final container = makeContainer();
      container.read(searchQueryProvider.notifier).set('2026-08');

      final ids = [
        for (final a in await container.read(searchAssetsProvider.future)) a.id,
      ];
      expect(ids, ['2026-8-0', '2026-8-1', '2026-8-2']);
    });

    test('a year query spans the whole year', () async {
      final container = makeContainer();
      container.read(searchQueryProvider.notifier).set('2026');
      expect(await container.read(searchAssetsProvider.future), hasLength(5));
    });

    test('the videos facet returns only videos (no date needed)', () async {
      final container = makeContainer(
        videoDurations: const {'2026-8-0': Duration(seconds: 5)},
      );
      container.read(searchTypeProvider.notifier).set(MediaTypeFilter.videos);

      final ids = [
        for (final a in await container.read(searchAssetsProvider.future)) a.id,
      ];
      expect(ids, ['2026-8-0']);
    });

    test('favorites-only sources from the favorites set', () async {
      final container = makeContainer(
        favorites: [
          Favorite(assetId: '2026-8-1', favoritedAt: DateTime(2026, 8, 1)),
          Favorite(assetId: '2026-7-0', favoritedAt: DateTime(2026, 7, 1)),
        ],
      );
      container.read(searchFavoritesOnlyProvider.notifier).toggle();

      final ids = [
        for (final a in await container.read(searchAssetsProvider.future)) a.id,
      ];
      expect(ids, ['2026-8-1', '2026-7-0']); // newest first
    });

    test('favorites-only composes with the date window', () async {
      final container = makeContainer(
        favorites: [
          Favorite(assetId: '2026-8-1', favoritedAt: DateTime(2026, 8, 1)),
          Favorite(assetId: '2026-7-0', favoritedAt: DateTime(2026, 7, 1)),
        ],
      );
      container.read(searchFavoritesOnlyProvider.notifier).toggle();
      container.read(searchQueryProvider.notifier).set('july 2026');

      final ids = [
        for (final a in await container.read(searchAssetsProvider.future)) a.id,
      ];
      expect(ids, ['2026-7-0']);
    });
  });

  group('searchAlbumsProvider', () {
    ProviderContainer albumContainer(List<AlbumSummary> albums) {
      final container = ProviderContainer(
        overrides: [
          photoLibraryServiceProvider
              .overrideWithValue(FakePhotoLibraryService()),
          albumSummariesProvider.overrideWith((ref) => Stream.value(albums)),
        ],
      );
      addTearDown(container.dispose);
      container.listen(searchAlbumsProvider, (_, _) {});
      // Let the overridden stream emit its first value.
      return container;
    }

    const albums = [
      AlbumSummary(id: 1, name: 'Iceland 2026', entryCount: 12, coverAssetId: 'a'),
      AlbumSummary(id: 2, name: 'Family', entryCount: 4, coverAssetId: 'b'),
    ];

    // Let both the overridden stream emit and Riverpod's scheduler flush the
    // resulting recompute before reading (a microtask alone isn't enough).
    Future<void> flush() => Future<void>.delayed(const Duration(milliseconds: 10));

    test('is empty while the query is blank', () async {
      final container = albumContainer(albums);
      await flush();
      expect(container.read(searchAlbumsProvider), isEmpty);
    });

    test('matches album names case-insensitively (substring)', () async {
      final container = albumContainer(albums);
      container.read(searchQueryProvider.notifier).set('ice');
      await flush();

      final names = [for (final a in container.read(searchAlbumsProvider)) a.name];
      expect(names, ['Iceland 2026']);
    });

    test('returns no matches for unrelated text', () async {
      final container = albumContainer(albums);
      container.read(searchQueryProvider.notifier).set('zzz');
      await flush();
      expect(container.read(searchAlbumsProvider), isEmpty);
    });
  });

  group('searchAssetsProvider content search (labels)', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    Future<ProviderContainer> seededContainer() async {
      await db.indexDao.upsertIndexed(
        assetId: 'p1',
        createdAt: DateTime(2026, 8, 10),
        isVideo: false,
        width: 1,
        height: 1,
        labels: const [('Dog', 0.9)],
        text: 'Birthday party invitation',
      );
      await db.indexDao.upsertIndexed(
        assetId: 'v1',
        createdAt: DateTime(2026, 7, 10),
        isVideo: true,
        width: 1,
        height: 1,
        labels: const [('Dog', 0.8)],
        text: '',
      );
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          photoLibraryServiceProvider
              .overrideWithValue(FakePhotoLibraryService()),
        ],
      );
      addTearDown(container.dispose);
      container.listen(searchAssetsProvider, (_, _) {});
      return container;
    }

    test('a free-text query matches ML labels', () async {
      final container = await seededContainer();
      container.read(searchQueryProvider.notifier).set('dog');
      final ids = [
        for (final a in await container.read(searchAssetsProvider.future)) a.id,
      ];
      expect(ids, ['p1', 'v1']); // newest first
    });

    test('content search still honors the media-type facet', () async {
      final container = await seededContainer();
      container.read(searchQueryProvider.notifier).set('dog');
      container.read(searchTypeProvider.notifier).set(MediaTypeFilter.videos);
      final ids = [
        for (final a in await container.read(searchAssetsProvider.future)) a.id,
      ];
      expect(ids, ['v1']);
    });

    test('content search honors favorites via the DB join', () async {
      final container = await seededContainer();
      await db.favoritesDao.add('v1');
      container.read(searchQueryProvider.notifier).set('dog');
      container.read(searchFavoritesOnlyProvider.notifier).toggle();
      final ids = [
        for (final a in await container.read(searchAssetsProvider.future)) a.id,
      ];
      expect(ids, ['v1']);
    });

    test('unmatched text yields no photo results', () async {
      final container = await seededContainer();
      container.read(searchQueryProvider.notifier).set('spaceship');
      expect(await container.read(searchAssetsProvider.future), isEmpty);
    });
  });
}
