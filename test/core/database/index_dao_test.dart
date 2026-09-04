import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/core/database/app_database.dart';
import 'package:sologallery/features/library/domain/year_month.dart';
import 'package:sologallery/features/search/domain/search_date.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> seed() async {
    await db.indexDao.upsertIndexed(
      assetId: 'a',
      createdAt: DateTime(2026, 8, 10),
      isVideo: false,
      width: 100,
      height: 100,
      labels: const [('Dog', 0.9), ('Grass', 0.8)],
      text: '',
    );
    await db.indexDao.upsertIndexed(
      assetId: 'b',
      createdAt: DateTime(2026, 7, 10),
      isVideo: true,
      width: 100,
      height: 100,
      labels: const [('Dog', 0.7)],
      text: '',
    );
    await db.indexDao.upsertIndexed(
      assetId: 'c',
      createdAt: DateTime(2026, 6, 10),
      isVideo: false,
      width: 100,
      height: 100,
      labels: const [('Beach', 0.95)],
      text: 'Sunset Beach Cafe menu',
    );
  }

  Future<List<String>> search(
    String query, {
    DateTime? min,
    DateTime? max,
    MediaTypeFilter type = MediaTypeFilter.all,
    bool favoritesOnly = false,
    int limit = 50,
    int offset = 0,
  }) async {
    final rows = await db.indexDao.searchContent(
      query: query,
      min: min,
      max: max,
      type: type,
      favoritesOnly: favoritesOnly,
      limit: limit,
      offset: offset,
    );
    return [for (final r in rows) r.id];
  }

  // --- Metadata sweep + grid reads ---------------------------------------

  test('upsertMetadata caches rows as ML-pending, newest first', () async {
    await db.indexDao.upsertMetadata([
      (
        id: 'a',
        createdAt: DateTime(2026, 8, 10),
        isVideo: false,
        width: 1,
        height: 1,
        isDated: true,
      ),
      (
        id: 'b',
        createdAt: DateTime(2026, 6, 10),
        isVideo: false,
        width: 1,
        height: 1,
        isDated: true,
      ),
    ]);
    expect(await db.indexDao.allCachedIds(), {'a', 'b'});
    // Both await ML, newest capture first.
    expect(await db.indexDao.pendingMlIds(), ['a', 'b']);
  });

  test(
    'a later sweep does not reset an already-ML\'d row to pending',
    () async {
      await db.indexDao.upsertMetadata([
        (
          id: 'a',
          createdAt: DateTime(2026, 8, 10),
          isVideo: false,
          width: 1,
          height: 1,
          isDated: true,
        ),
      ]);
      await db.indexDao.upsertIndexed(
        assetId: 'a',
        createdAt: DateTime(2026, 8, 10),
        isVideo: false,
        width: 1,
        height: 1,
        labels: const [('Dog', 0.9)],
        text: '',
      );
      expect(await db.indexDao.pendingMlIds(), isEmpty);
      // Re-sweep with the same metadata — indexedAt must be preserved.
      await db.indexDao.upsertMetadata([
        (
          id: 'a',
          createdAt: DateTime(2026, 8, 10),
          isVideo: false,
          width: 1,
          height: 1,
          isDated: true,
        ),
      ]);
      expect(await db.indexDao.pendingMlIds(), isEmpty);
      expect(await search('dog'), ['a']); // labels survive the re-sweep
    },
  );

  test('deleteAssets prunes rows and cascades to labels/text', () async {
    await seed();
    expect(await db.indexDao.allCachedIds(), {'a', 'b', 'c'});
    await db.indexDao.deleteAssets(['a', 'b']);
    expect(await db.indexDao.allCachedIds(), {'c'});
    expect(await search('dog'), isEmpty); // a, b (and their labels) gone
  });

  group('isVideoInCache', () {
    test('is true for a cached video row', () async {
      await seed(); // b is a video
      expect(await db.indexDao.isVideoInCache('b'), isTrue);
    });

    test('is false for a cached image row', () async {
      await seed(); // a is a photo
      expect(await db.indexDao.isVideoInCache('a'), isFalse);
    });

    test('is false for an id not yet in the cache', () async {
      expect(await db.indexDao.isVideoInCache('unknown'), isFalse);
    });
  });

  /// Seeds one dated asset per [dates] entry, ids `s0`, `s1`, … — enough for
  /// the grouping queries, which read only `created_at` and `is_dated`.
  Future<void> seedDates(List<DateTime> dates) async {
    await db.indexDao.upsertMetadata([
      for (final (i, d) in dates.indexed)
        (
          id: 's$i',
          createdAt: d,
          isVideo: false,
          width: 1,
          height: 1,
          isDated: true,
        ),
    ]);
  }

  group('watchYearCounts', () {
    test('groups dated assets by year, newest first', () async {
      await seedDates([
        DateTime(2026, 8, 10),
        DateTime(2026, 2, 3),
        DateTime(2025, 12, 31),
        DateTime(2024, 1, 1),
      ]);
      final counts = await db.indexDao.watchYearCounts().first;
      expect(counts.map((e) => e.year).toList(), [2026, 2025, 2024]);
      expect(counts.map((e) => e.count).toList(), [2, 1, 1]);
    });

    test('is empty on an empty cache', () async {
      expect(await db.indexDao.watchYearCounts().first, isEmpty);
    });

    test('excludes undated assets, which belong to no year', () async {
      await db.indexDao.upsertMetadata([
        (
          id: 'd',
          createdAt: DateTime(2026, 8, 1),
          isVideo: false,
          width: 1,
          height: 1,
          isDated: true,
        ),
        (
          id: 'u',
          createdAt: DateTime(2020, 1, 1),
          isVideo: false,
          width: 1,
          height: 1,
          isDated: false,
        ),
      ]);
      final counts = await db.indexDao.watchYearCounts().first;
      expect(counts.map((e) => e.year).toList(), [2026]);
      expect(counts.single.count, 1);
    });

    test('buckets a local New Year boundary by local time, not UTC', () async {
      // The UTC-extraction bug this guards against files a local-Jan-1 00:00
      // capture under the previous year anywhere west of UTC. Both instants
      // are local DateTimes, so each must land in its own local year.
      await seedDates([
        DateTime(2026, 1, 1, 0, 0),
        DateTime(2025, 12, 31, 23, 59),
      ]);
      final counts = await db.indexDao.watchYearCounts().first;
      expect(counts.map((e) => e.year).toList(), [2026, 2025]);
      expect(counts.map((e) => e.count).toList(), [1, 1]);
    });

    test('agrees with watchMonthCounts on the total', () async {
      await seedDates([
        DateTime(2026, 8, 10),
        DateTime(2026, 8, 11),
        DateTime(2026, 3, 1),
        DateTime(2025, 5, 5),
      ]);
      final byYear = await db.indexDao.watchYearCounts().first;
      final byMonth = await db.indexDao.watchMonthCounts().first;
      int total(Iterable<int> counts) => counts.fold(0, (a, b) => a + b);
      expect(
        total(byYear.map((e) => e.count)),
        total(byMonth.map((e) => e.count)),
      );
      // And the two axes must agree on which years exist at all.
      expect(
        byYear.map((e) => e.year).toSet(),
        byMonth.map((e) => e.month.year).toSet(),
      );
    });
  });

  group('watchYearPreviews', () {
    test('returns the newest ids within the year, newest first', () async {
      await seedDates([
        DateTime(2026, 1, 1), // s0
        DateTime(2026, 12, 31), // s1
        DateTime(2026, 6, 15), // s2
        DateTime(2025, 12, 31), // s3 — different year
      ]);
      expect(await db.indexDao.watchYearPreviews(2026).first, [
        's1',
        's2',
        's0',
      ]);
    });

    test('caps at the limit', () async {
      await seedDates([for (var d = 1; d <= 10; d++) DateTime(2026, 1, d)]);
      expect(await db.indexDao.watchYearPreviews(2026).first, hasLength(6));
      expect(
        await db.indexDao.watchYearPreviews(2026, limit: 2).first,
        hasLength(2),
      );
    });

    test('is empty for a year with nothing in it', () async {
      await seedDates([DateTime(2026, 1, 1)]);
      expect(await db.indexDao.watchYearPreviews(2019).first, isEmpty);
    });

    test('excludes undated assets', () async {
      await db.indexDao.upsertMetadata([
        (
          id: 'u',
          createdAt: DateTime(2026, 5, 5),
          isVideo: false,
          width: 1,
          height: 1,
          isDated: false,
        ),
      ]);
      expect(await db.indexDao.watchYearPreviews(2026).first, isEmpty);
    });
  });

  group('watchRecentSince', () {
    test('returns only assets on or after the cutoff, newest first', () async {
      final now = DateTime(2026, 7, 20, 12);
      await seedDates([
        now.subtract(const Duration(days: 1)), // s0 — in
        now.subtract(const Duration(days: 30)), // s1 — out
        now.subtract(const Duration(hours: 2)), // s2 — in
      ]);
      final cutoff = now.subtract(const Duration(days: 7));
      final recent = await db.indexDao.watchRecentSince(cutoff).first;
      expect(recent.map((a) => a.id).toList(), ['s2', 's0']);
    });

    test('includes an asset exactly on the cutoff', () async {
      final cutoff = DateTime(2026, 7, 13);
      await seedDates([cutoff]);
      expect(await db.indexDao.watchRecentSince(cutoff).first, hasLength(1));
    });

    test('excludes an asset one second before the cutoff', () async {
      final cutoff = DateTime(2026, 7, 13);
      await seedDates([cutoff.subtract(const Duration(seconds: 1))]);
      expect(await db.indexDao.watchRecentSince(cutoff).first, isEmpty);
    });

    test('holds a local midnight boundary', () async {
      // Local midnight, the boundary the This-week cutoff lands on when the
      // user opens the app at midnight — must not shift by the UTC offset.
      final midnight = DateTime(2026, 7, 13);
      await seedDates([
        midnight.subtract(const Duration(minutes: 1)),
        midnight.add(const Duration(minutes: 1)),
      ]);
      final recent = await db.indexDao.watchRecentSince(midnight).first;
      expect(recent, hasLength(1));
      expect(recent.single.createdAt.day, 13);
    });

    test(
      'excludes undated assets — they have no capture time to window',
      () async {
        await db.indexDao.upsertMetadata([
          (
            id: 'u',
            createdAt: DateTime(2026, 7, 19),
            isVideo: false,
            width: 1,
            height: 1,
            isDated: false,
          ),
        ]);
        final recent = await db.indexDao
            .watchRecentSince(DateTime(2026, 7, 1))
            .first;
        expect(recent, isEmpty);
      },
    );

    test('is empty when nothing falls in the window', () async {
      await seedDates([DateTime(2020, 1, 1)]);
      expect(
        await db.indexDao.watchRecentSince(DateTime(2026, 7, 13)).first,
        isEmpty,
      );
    });

    test('caps at the limit, keeping the newest', () async {
      await seedDates([for (var d = 1; d <= 5; d++) DateTime(2026, 7, d)]);
      final recent = await db.indexDao
          .watchRecentSince(DateTime(2026, 1, 1), limit: 2)
          .first;
      expect(recent.map((a) => a.id).toList(), ['s4', 's3']);
    });
  });

  test('watchMonthCounts groups dated assets by month, newest first', () async {
    await seed(); // a:2026-08, b:2026-07, c:2026-06
    final counts = await db.indexDao.watchMonthCounts().first;
    expect(counts.map((e) => e.month).toList(), const [
      YearMonth(2026, 8),
      YearMonth(2026, 7),
      YearMonth(2026, 6),
    ]);
    expect(counts.map((e) => e.count).toList(), [1, 1, 1]);
  });

  test('undated assets route to Older, not to month counts', () async {
    await db.indexDao.upsertMetadata([
      (
        id: 'd',
        createdAt: DateTime(2026, 8, 1),
        isVideo: false,
        width: 1,
        height: 1,
        isDated: true,
      ),
      (
        id: 'u',
        createdAt: DateTime(2020, 1, 1),
        isVideo: false,
        width: 1,
        height: 1,
        isDated: false,
      ),
    ]);
    final counts = await db.indexDao.watchMonthCounts().first;
    expect(counts.map((e) => e.month).toList(), const [YearMonth(2026, 8)]);
    expect(await db.indexDao.watchOlderCount().first, 1);
    expect(await db.indexDao.watchOlderPreviews().first, ['u']);
    final month = await db.indexDao.monthAssets(
      const YearMonth(2026, 8),
      limit: 10,
      offset: 0,
    );
    expect(month.map((a) => a.id).toList(), ['d']);
  });

  test(
    'watchMonthPreviews caps and monthAssets paginates, newest first',
    () async {
      await db.indexDao.upsertMetadata([
        for (var i = 1; i <= 8; i++)
          (
            id: 'm$i',
            createdAt: DateTime(2026, 8, i),
            isVideo: false,
            width: 1,
            height: 1,
            isDated: true,
          ),
      ]);
      const aug = YearMonth(2026, 8);
      expect(
        (await db.indexDao.watchMonthPreviews(aug).first).length,
        6,
      ); // capped
      expect(await db.indexDao.watchMonthPreviews(aug).first, [
        'm8',
        'm7',
        'm6',
        'm5',
        'm4',
        'm3',
      ]);
      final page0 = await db.indexDao.monthAssets(aug, limit: 5, offset: 0);
      final page1 = await db.indexDao.monthAssets(aug, limit: 5, offset: 5);
      expect(page0.map((a) => a.id).toList(), ['m8', 'm7', 'm6', 'm5', 'm4']);
      expect(page1.map((a) => a.id).toList(), ['m3', 'm2', 'm1']);
    },
  );

  test('watchMonthAssets/watchOlderAssets re-emit on cache change', () async {
    const aug = YearMonth(2026, 8);
    await db.indexDao.upsertMetadata([
      (
        id: 'd1',
        createdAt: DateTime(2026, 8, 1),
        isVideo: false,
        width: 1,
        height: 1,
        isDated: true,
      ),
      (
        id: 'u1',
        createdAt: DateTime(2020, 1, 1),
        isVideo: false,
        width: 1,
        height: 1,
        isDated: false,
      ),
    ]);
    final month = <List<String>>[];
    final older = <List<String>>[];
    final monthSub = db.indexDao
        .watchMonthAssets(aug, limit: 90)
        .listen((rows) => month.add([for (final a in rows) a.id]));
    final olderSub = db.indexDao
        .watchOlderAssets(limit: 90)
        .listen((rows) => older.add([for (final a in rows) a.id]));
    addTearDown(monthSub.cancel);
    addTearDown(olderSub.cancel);

    await Future<void>.delayed(const Duration(milliseconds: 20)); // initial

    // A newer dated asset lands at the front; a new undated asset joins Older.
    await db.indexDao.upsertMetadata([
      (
        id: 'd2',
        createdAt: DateTime(2026, 8, 9),
        isVideo: false,
        width: 1,
        height: 1,
        isDated: true,
      ),
      (
        id: 'u2',
        createdAt: DateTime(2021, 1, 1),
        isVideo: false,
        width: 1,
        height: 1,
        isDated: false,
      ),
    ]);
    await Future<void>.delayed(const Duration(milliseconds: 20)); // re-emit

    expect(month, [
      ['d1'],
      ['d2', 'd1'],
    ]);
    expect(older, [
      ['u1'],
      ['u2', 'u1'],
    ]);
  });

  test('watchLibraryTotals counts photos and the video subset', () async {
    await seed(); // a (photo), b (video), c (photo)
    expect(await db.indexDao.watchLibraryTotals().first, (
      photos: 3,
      videos: 1,
    ));
  });

  test('clearIndex wipes the cache and cascades labels/OCR/faces', () async {
    await seed();
    await db.facesDao.insertFaces('a', [
      (left: 0, top: 0, right: 1, bottom: 1, embedding: Float32List(4)),
    ]);
    expect(await db.indexDao.allCachedIds(), isNotEmpty);

    final cleared = await db.indexDao.clearIndex();
    expect(cleared, 3);
    expect(await db.indexDao.allCachedIds(), isEmpty);
    expect(await db.select(db.photoLabels).get(), isEmpty); // cascaded
    expect(await db.select(db.photoTexts).get(), isEmpty); // cascaded
    expect(await db.select(db.faceEmbeddings).get(), isEmpty); // cascaded
  });

  test(
    'watchFavoritesInCache drops favorites whose asset is not cached',
    () async {
      await seed(); // a, b, c cached
      await db.favoritesDao.add('a', at: DateTime(2026, 1, 2));
      await db.favoritesDao.add('z', at: DateTime(2026, 1, 3)); // not cached
      final favs = await db.indexDao.watchFavoritesInCache().first;
      expect(favs.map((f) => f.assetId).toList(), [
        'a',
      ]); // z (dangling) dropped
    },
  );

  test('watchFavoritesInCache orders most-recently-favorited first', () async {
    await seed(); // a, b, c cached
    await db.favoritesDao.add('a', at: DateTime(2020, 1, 1));
    await db.favoritesDao.add('b', at: DateTime(2024, 1, 1));
    final favs = await db.indexDao.watchFavoritesInCache().first;
    expect(favs.map((f) => f.assetId).toList(), ['b', 'a']);
  });

  test('watchFavoritesInCache carries the cached pixel dimensions', () async {
    // The Saved grid is a masonry layout and cannot place a cell without
    // knowing its aspect ratio, so the join has to bring the numbers back.
    await db.indexDao.upsertMetadata([
      (
        id: 'wide',
        createdAt: DateTime(2026, 5, 1),
        isVideo: false,
        width: 4032,
        height: 3024,
        isDated: true,
      ),
      (
        id: 'tall',
        createdAt: DateTime(2026, 5, 2),
        isVideo: false,
        width: 3024,
        height: 4032,
        isDated: true,
      ),
    ]);
    await db.favoritesDao.add('wide', at: DateTime(2026, 6, 1));
    await db.favoritesDao.add('tall', at: DateTime(2026, 6, 2));

    final favs = await db.indexDao.watchFavoritesInCache().first;
    final byId = {for (final f in favs) f.assetId: f};
    expect(byId['wide']!.width, 4032);
    expect(byId['wide']!.height, 3024);
    expect(byId['tall']!.width, 3024);
    expect(byId['tall']!.height, 4032);
    expect(byId['tall']!.favoritedAt, DateTime(2026, 6, 2));
  });

  test('watchFavoritesInCache re-emits when a favorite is added', () async {
    await seed(); // a, b, c cached
    await db.favoritesDao.add('a', at: DateTime(2026, 1, 1));

    final emissions = <List<String>>[];
    final sub = db.indexDao.watchFavoritesInCache().listen(
      (rows) => emissions.add([for (final r in rows) r.assetId]),
    );
    addTearDown(sub.cancel);

    // Let the initial query resolve before mutating — a mutation that races it
    // coalesces both emissions into one and the "before" state is never seen.
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await db.favoritesDao.add('b', at: DateTime(2026, 2, 1));
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(emissions.first, ['a']);
    expect(emissions.last, ['b', 'a']);
  });

  test(
    'matches a label as a case-insensitive substring, newest first',
    () async {
      await seed();
      expect(await search('dog'), ['a', 'b']);
      expect(await search('DOG'), ['a', 'b']);
      expect(await search('gra'), ['a']); // "Grass"
      expect(await search('cat'), isEmpty);
    },
  );

  test('dedupes to one row per asset despite multiple labels', () async {
    await db.indexDao.upsertIndexed(
      assetId: 'x',
      createdAt: DateTime(2026, 8, 1),
      isVideo: false,
      width: 1,
      height: 1,
      labels: const [('Dog', 0.9), ('Doggo', 0.8)], // both match "dog"
      text: 'dog dog dog', // text also matches — still one row
    );
    expect(await search('dog'), ['x']);
  });

  test('matches OCR text as well as labels', () async {
    await seed();
    // "cafe" is only in c's OCR text, not any label.
    expect(await search('cafe'), ['c']);
    // "menu" (text) and "beach" (label) both resolve to c.
    expect(await search('menu'), ['c']);
    expect(await search('beach'), ['c']);
  });

  test('OCR text respects the facets (favorites)', () async {
    await seed();
    await db.favoritesDao.add('c');
    expect(await search('cafe', favoritesOnly: true), ['c']);
    await db.favoritesDao.remove('c');
    expect(await search('cafe', favoritesOnly: true), isEmpty);
  });

  test('applies the media-type facet', () async {
    await seed();
    expect(await search('dog', type: MediaTypeFilter.photos), ['a']);
    expect(await search('dog', type: MediaTypeFilter.videos), ['b']);
  });

  test('applies the capture-date window', () async {
    await seed();
    expect(
      await search('dog', min: DateTime(2026, 8), max: DateTime(2026, 9)),
      ['a'],
    );
  });

  test('applies the favorites facet via join', () async {
    await seed();
    await db.favoritesDao.add('b');
    expect(await search('dog', favoritesOnly: true), ['b']);
    expect(await search('dog', favoritesOnly: false), ['a', 'b']);
  });

  test('paginates with limit/offset', () async {
    await seed();
    expect(await search('dog', limit: 1, offset: 0), ['a']);
    expect(await search('dog', limit: 1, offset: 1), ['b']);
    expect(await search('dog', limit: 1, offset: 2), isEmpty);
  });

  test('re-indexing replaces the previous label set', () async {
    await seed();
    await db.indexDao.upsertIndexed(
      assetId: 'a',
      createdAt: DateTime(2026, 8, 10),
      isVideo: false,
      width: 100,
      height: 100,
      labels: const [('Cat', 0.9)],
      text: '',
    );
    expect(await search('dog'), ['b']); // a's Dog label is gone
    expect(await search('cat'), ['a']);
  });

  test('deleting a photo_asset cascades to its labels', () async {
    await seed();
    await (db.delete(db.photoAssets)..where((t) => t.assetId.equals('a'))).go();
    expect(await search('dog'), ['b']);
    final labels = await db.select(db.photoLabels).get();
    expect(labels.where((l) => l.assetId == 'a'), isEmpty);
  });

  // --- Browse labels (Search idle chips) ----------------------------------

  /// Indexes [n] assets, each carrying every label in [labels].
  Future<void> seedLabeled(int n, List<String> labels, {int from = 0}) async {
    for (var i = from; i < from + n; i++) {
      await db.indexDao.upsertIndexed(
        assetId: 'x$i',
        createdAt: DateTime(2026, 1, 1).add(Duration(days: i)),
        isVideo: false,
        width: 100,
        height: 100,
        labels: [for (final l in labels) (l, 0.9)],
        text: '',
      );
    }
  }

  Future<List<({String label, int count})>> topLabels({
    Set<String> allow = const {'Beach', 'Cat', 'Dog', 'Sunset'},
    int limit = 10,
  }) => db.indexDao.watchTopLabels(allow: allow, limit: limit).first;

  test('watchTopLabels ranks by asset count, most first', () async {
    await seedLabeled(3, ['Dog']);
    await seedLabeled(2, ['Cat'], from: 10);
    await seedLabeled(1, ['Beach'], from: 20);

    expect(await topLabels(), [
      (label: 'Dog', count: 3),
      (label: 'Cat', count: 2),
      (label: 'Beach', count: 1),
    ]);
  });

  test('watchTopLabels breaks count ties alphabetically', () async {
    await seedLabeled(2, ['Sunset']);
    await seedLabeled(2, ['Cat'], from: 10);

    expect(
      [for (final r in await topLabels()) r.label],
      ['Cat', 'Sunset'],
    );
  });

  test('watchTopLabels keeps only allowlisted labels', () async {
    // 'Grass' outnumbers everything but is not browsable.
    await seedLabeled(5, ['Grass']);
    await seedLabeled(1, ['Dog']);

    expect(await topLabels(), [(label: 'Dog', count: 1)]);
  });

  test('watchTopLabels counts each asset once per label', () async {
    // The same label emitted twice for one photo is still one photo.
    await db.indexDao.upsertIndexed(
      assetId: 'dup',
      createdAt: DateTime(2026, 1, 1),
      isVideo: false,
      width: 100,
      height: 100,
      labels: const [('Dog', 0.9), ('Dog', 0.5)],
      text: '',
    );
    expect(await topLabels(), [(label: 'Dog', count: 1)]);
  });

  test('watchTopLabels caps at the limit, keeping the biggest', () async {
    await seedLabeled(3, ['Dog']);
    await seedLabeled(2, ['Cat'], from: 10);
    await seedLabeled(1, ['Beach'], from: 20);

    expect(
      [for (final r in await topLabels(limit: 2)) r.label],
      ['Dog', 'Cat'],
    );
  });

  test('watchTopLabels is empty on a library with no labels', () async {
    expect(await topLabels(), isEmpty);
  });

  test('watchTopLabels re-emits as the indexer labels more photos', () async {
    final emissions = <List<String>>[];
    final sub = db.indexDao
        .watchTopLabels(allow: const {'Cat', 'Dog'})
        .listen((rows) => emissions.add([for (final r in rows) r.label]));
    addTearDown(sub.cancel);

    // Let the initial (empty) result land before mutating, or the two
    // emissions coalesce (docs/gotchas.md gotcha).
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await seedLabeled(1, ['Dog']);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(emissions.first, isEmpty);
    expect(emissions.last, ['Dog']);
  });

  // --- Recently viewed -------------------------------------------------------

  group('recordView + watchRecentlyViewed', () {
    test('orders views newest first', () async {
      // Seed two older explicit views, then record a fresh one through the DAO.
      await db.into(db.recentlyViewed).insert(
        RecentlyViewedData(assetId: 'a', viewedAt: DateTime(2026, 1, 1)),
      );
      await db.into(db.recentlyViewed).insert(
        RecentlyViewedData(assetId: 'b', viewedAt: DateTime(2026, 1, 2)),
      );
      await db.indexDao.recordView('c');

      expect(
        await db.indexDao.watchRecentlyViewed(limit: 10).first,
        ['c', 'b', 'a'],
      );
    });

    test('caps at the limit', () async {
      for (final (i, id) in ['a', 'b', 'c'].indexed) {
        await db.into(db.recentlyViewed).insert(
          RecentlyViewedData(
            assetId: id,
            viewedAt: DateTime(2026, 1, 1).add(Duration(days: i)),
          ),
        );
      }

      expect(await db.indexDao.watchRecentlyViewed(limit: 2).first, [
        'c',
        'b',
      ]);
    });

    test('upserts: re-viewing moves an asset to the top', () async {
      final first = DateTime(2026, 1, 1, 12);
      final second = DateTime(2026, 1, 2, 12);
      final third = DateTime(2026, 1, 3, 12);

      // Use the DAO's public API, but travel the timestamps so the ordering is
      // deterministic without racing DateTime.now().
      await db.into(db.recentlyViewed).insert(
        RecentlyViewedData(assetId: 'a', viewedAt: first),
      );
      await db.into(db.recentlyViewed).insert(
        RecentlyViewedData(assetId: 'b', viewedAt: second),
      );
      await db.into(db.recentlyViewed).insert(
        RecentlyViewedData(assetId: 'c', viewedAt: third),
      );

      expect(
        await db.indexDao.watchRecentlyViewed(limit: 10).first,
        ['c', 'b', 'a'],
      );

      // Re-view 'a' via the DAO; it should now be newest.
      await db.indexDao.recordView('a');
      final ids = await db.indexDao.watchRecentlyViewed(limit: 10).first;
      expect(ids.first, 'a');
      expect(ids, hasLength(3));
    });

    test('is empty when nothing has been viewed', () async {
      expect(await db.indexDao.watchRecentlyViewed().first, isEmpty);
    });
  });
}
