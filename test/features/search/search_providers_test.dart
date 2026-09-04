import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/core/database/app_database.dart'
    show AppDatabase, RecentlyViewedData;
import 'package:sologallery/core/database/daos/index_dao.dart'
    show FavoriteAsset, IndexDao;
import 'package:sologallery/core/database/daos/albums_dao.dart'
    show AlbumSummary;
import 'package:sologallery/core/database/database_provider.dart';
import 'package:sologallery/features/albums/albums_providers.dart';
import 'package:sologallery/features/saved/saved_providers.dart';
import 'package:sologallery/features/search/domain/search_date.dart';
import 'package:sologallery/features/search/search_providers.dart';
import 'package:sologallery/services/permission_provider.dart';
import 'package:sologallery/services/photo_library_service.dart';

import '../../support/asset_fixtures.dart';
import '../../support/fake_photo_library_service.dart';

/// A fake [IndexDao] whose top-labels stream is fully controlled by the test,
/// so `topBrowseLabelsProvider`'s `distinct(listEquals)` can be asserted
/// against a stream shaped exactly like Drift's real re-emission behaviour (a
/// fresh row list per emission) without depending on Drift's own re-emission
/// timing.
class _FakeIndexDao extends IndexDao {
  _FakeIndexDao(super.db, this._stream);

  final Stream<List<({String label, int count})>> _stream;

  @override
  Stream<List<({String label, int count})>> watchTopLabels({
    required Set<String> allow,
    int limit = 10,
  }) => _stream;
}

void main() {
  // Aug 2026 (3 assets, the first a video) + Jul 2026 (2 assets), newest first.
  List<AssetRef> library() => [
    ...assetsInMonth(2026, 8, 3),
    ...assetsInMonth(2026, 7, 2),
  ];

  ProviderContainer makeContainer({
    List<AssetRef>? assets,
    Map<String, Duration> videoDurations = const {},
    List<FavoriteAsset> favorites = const [],
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
          (
            assetId: '2026-8-1',
            favoritedAt: DateTime(2026, 8, 1),
            width: 1,
            height: 1,
          ),
          (
            assetId: '2026-7-0',
            favoritedAt: DateTime(2026, 7, 1),
            width: 1,
            height: 1,
          ),
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
          (
            assetId: '2026-8-1',
            favoritedAt: DateTime(2026, 8, 1),
            width: 1,
            height: 1,
          ),
          (
            assetId: '2026-7-0',
            favoritedAt: DateTime(2026, 7, 1),
            width: 1,
            height: 1,
          ),
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
          photoLibraryServiceProvider.overrideWithValue(
            FakePhotoLibraryService(),
          ),
          albumSummariesProvider.overrideWith((ref) => Stream.value(albums)),
        ],
      );
      addTearDown(container.dispose);
      container.listen(searchAlbumsProvider, (_, _) {});
      // Let the overridden stream emit its first value.
      return container;
    }

    const albums = [
      AlbumSummary(
        id: 1,
        name: 'Iceland 2026',
        entryCount: 12,
        coverAssetId: 'a',
      ),
      AlbumSummary(id: 2, name: 'Family', entryCount: 4, coverAssetId: 'b'),
    ];

    // Let both the overridden stream emit and Riverpod's scheduler flush the
    // resulting recompute before reading (a microtask alone isn't enough).
    Future<void> flush() =>
        Future<void>.delayed(const Duration(milliseconds: 10));

    test('is empty while the query is blank', () async {
      final container = albumContainer(albums);
      await flush();
      expect(container.read(searchAlbumsProvider), isEmpty);
    });

    test('matches album names case-insensitively (substring)', () async {
      final container = albumContainer(albums);
      container.read(searchQueryProvider.notifier).set('ice');
      await flush();

      final names = [
        for (final a in container.read(searchAlbumsProvider)) a.name,
      ];
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
          photoLibraryServiceProvider.overrideWithValue(
            FakePhotoLibraryService(),
          ),
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

  group('topBrowseLabelsProvider', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    /// Indexes one asset per entry, carrying that entry's label.
    Future<void> seedLabels(Map<String, int> countByLabel) async {
      var i = 0;
      for (final entry in countByLabel.entries) {
        for (var n = 0; n < entry.value; n++) {
          await db.indexDao.upsertIndexed(
            assetId: 'a${i++}',
            createdAt: DateTime(2026, 1, 1),
            isVideo: false,
            width: 1,
            height: 1,
            labels: [(entry.key, 0.9)],
            text: '',
          );
        }
      }
    }

    /// Subscribes (never awaits an autoDispose stream's `.future` — AGENTS.md)
    /// and returns the emitted chip list.
    Future<List<String>> read() async {
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);
      container.listen(topBrowseLabelsProvider, (_, _) {});
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return container.read(topBrowseLabelsProvider).value ?? const [];
    }

    test('offers the most-carried labels, most photos first', () async {
      await seedLabels({'Beach': 1, 'Dog': 3, 'Cat': 2});
      expect(await read(), ['Dog', 'Cat', 'Beach']);
    });

    test('drops labels outside the presentable allowlist', () async {
      // ML Kit's coarse output must not reach the chips, however common.
      await seedLabels({'Person': 9, 'Room': 8, 'Dog': 1});
      expect(await read(), ['Dog']);
    });

    test('caps the row at ten chips', () async {
      await seedLabels({
        for (final l in [
          'Beach',
          'Bicycle',
          'Bird',
          'Boat',
          'Bridge',
          'Cat',
          'Dog',
          'Flower',
          'Food',
          'Forest',
          'Garden',
          'Lake',
        ])
          l: 1,
      });
      expect((await read()).length, browseLabelCount);
    });

    test('is empty while nothing is labeled yet', () async {
      expect(await read(), isEmpty);
    });

    test('drops a duplicate emission and propagates a changed one', () async {
      final controller =
          StreamController<List<({String label, int count})>>();
      addTearDown(controller.close);
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          indexDaoProvider.overrideWithValue(
            _FakeIndexDao(db, controller.stream),
          ),
        ],
      );
      addTearDown(container.dispose);

      final emissions = <List<String>>[];
      container.listen(topBrowseLabelsProvider, (_, next) {
        next.whenData(emissions.add);
      });

      // Two structurally-equal but separately-allocated lists — matching how
      // Drift re-runs and re-emits the real GROUP BY on every unrelated
      // photo_label write, even when its result hasn't actually changed.
      controller.add([(label: 'Dog', count: 3)]);
      await pumpEventQueue();
      controller.add([(label: 'Dog', count: 3)]);
      await pumpEventQueue();
      expect(
        emissions.length,
        1,
        reason: 'the byte-for-byte-identical re-emission is dropped',
      );

      // A genuine change — here, a new label entering the top-N — must still
      // propagate.
      controller.add([(label: 'Dog', count: 3), (label: 'Cat', count: 2)]);
      await pumpEventQueue();
      expect(emissions.length, 2);
      expect(emissions.last, ['Dog', 'Cat']);
    });
  });

  group('recentlyViewedProvider', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    /// Seeds explicit view timestamps so ordering is deterministic without
    /// racing [DateTime.now].
    Future<void> seedViews(List<(String, DateTime)> entries) async {
      for (final (id, at) in entries) {
        await db.into(db.recentlyViewed).insert(
          RecentlyViewedData(assetId: id, viewedAt: at),
        );
      }
    }

    /// Subscribes and returns the emitted id list.
    Future<List<String>> read({int limit = 12}) async {
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);
      container.listen(recentlyViewedProvider(limit), (_, _) {});
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return container.read(recentlyViewedProvider(limit)).value ?? const [];
    }

    test('emits ids newest-first', () async {
      await seedViews([
        ('a', DateTime(2026, 1, 1)),
        ('b', DateTime(2026, 1, 2)),
        ('c', DateTime(2026, 1, 3)),
      ]);
      expect(await read(limit: 10), ['c', 'b', 'a']);
    });

    test('caps the list at the requested limit', () async {
      await seedViews([
        ('a', DateTime(2026, 1, 1)),
        ('b', DateTime(2026, 1, 2)),
        ('c', DateTime(2026, 1, 3)),
      ]);
      expect(await read(limit: 2), ['c', 'b']);
      expect((await read(limit: 5)).length, 3);
    });

    test('is empty when nothing has been viewed', () async {
      expect(await read(), isEmpty);
    });

    test('re-emits when a new view is recorded', () async {
      await seedViews([
        ('a', DateTime(2026, 1, 1)),
        ('b', DateTime(2026, 1, 2)),
      ]);

      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);
      final emissions = <List<String>>[];
      container.listen(
        recentlyViewedProvider(12),
        (_, value) => emissions.add(value.value ?? const []),
        fireImmediately: true,
      );

      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(emissions.last, ['b', 'a']);

      await db.indexDao.recordView('c');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(emissions.last, ['c', 'b', 'a']);
    });
  });
}
