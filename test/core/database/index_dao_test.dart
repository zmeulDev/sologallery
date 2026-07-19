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
      (id: 'a', createdAt: DateTime(2026, 8, 10), isVideo: false, width: 1, height: 1, isDated: true),
      (id: 'b', createdAt: DateTime(2026, 6, 10), isVideo: false, width: 1, height: 1, isDated: true),
    ]);
    expect(await db.indexDao.allCachedIds(), {'a', 'b'});
    // Both await ML, newest capture first.
    expect(await db.indexDao.pendingMlIds(), ['a', 'b']);
  });

  test('a later sweep does not reset an already-ML\'d row to pending', () async {
    await db.indexDao.upsertMetadata([
      (id: 'a', createdAt: DateTime(2026, 8, 10), isVideo: false, width: 1, height: 1, isDated: true),
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
      (id: 'a', createdAt: DateTime(2026, 8, 10), isVideo: false, width: 1, height: 1, isDated: true),
    ]);
    expect(await db.indexDao.pendingMlIds(), isEmpty);
    expect(await search('dog'), ['a']); // labels survive the re-sweep
  });

  test('deleteAssets prunes rows and cascades to labels/text', () async {
    await seed();
    expect(await db.indexDao.allCachedIds(), {'a', 'b', 'c'});
    await db.indexDao.deleteAssets(['a', 'b']);
    expect(await db.indexDao.allCachedIds(), {'c'});
    expect(await search('dog'), isEmpty); // a, b (and their labels) gone
  });

  test('watchMonthCounts groups dated assets by month, newest first', () async {
    await seed(); // a:2026-08, b:2026-07, c:2026-06
    final counts = await db.indexDao.watchMonthCounts().first;
    expect(counts.map((e) => e.month).toList(),
        const [YearMonth(2026, 8), YearMonth(2026, 7), YearMonth(2026, 6)]);
    expect(counts.map((e) => e.count).toList(), [1, 1, 1]);
  });

  test('undated assets route to Older, not to month counts', () async {
    await db.indexDao.upsertMetadata([
      (id: 'd', createdAt: DateTime(2026, 8, 1), isVideo: false, width: 1, height: 1, isDated: true),
      (id: 'u', createdAt: DateTime(2020, 1, 1), isVideo: false, width: 1, height: 1, isDated: false),
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

  test('watchMonthPreviews caps and monthAssets paginates, newest first',
      () async {
    await db.indexDao.upsertMetadata([
      for (var i = 1; i <= 8; i++)
        (id: 'm$i', createdAt: DateTime(2026, 8, i), isVideo: false, width: 1, height: 1, isDated: true),
    ]);
    const aug = YearMonth(2026, 8);
    expect((await db.indexDao.watchMonthPreviews(aug).first).length, 6); // capped
    expect(await db.indexDao.watchMonthPreviews(aug).first,
        ['m8', 'm7', 'm6', 'm5', 'm4', 'm3']);
    final page0 = await db.indexDao.monthAssets(aug, limit: 5, offset: 0);
    final page1 = await db.indexDao.monthAssets(aug, limit: 5, offset: 5);
    expect(page0.map((a) => a.id).toList(), ['m8', 'm7', 'm6', 'm5', 'm4']);
    expect(page1.map((a) => a.id).toList(), ['m3', 'm2', 'm1']);
  });

  test('watchMonthAssets/watchOlderAssets re-emit on cache change', () async {
    const aug = YearMonth(2026, 8);
    await db.indexDao.upsertMetadata([
      (id: 'd1', createdAt: DateTime(2026, 8, 1), isVideo: false, width: 1, height: 1, isDated: true),
      (id: 'u1', createdAt: DateTime(2020, 1, 1), isVideo: false, width: 1, height: 1, isDated: false),
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
      (id: 'd2', createdAt: DateTime(2026, 8, 9), isVideo: false, width: 1, height: 1, isDated: true),
      (id: 'u2', createdAt: DateTime(2021, 1, 1), isVideo: false, width: 1, height: 1, isDated: false),
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
    expect(await db.indexDao.watchLibraryTotals().first, (photos: 3, videos: 1));
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

  test('watchFavoritesInCache drops favorites whose asset is not cached',
      () async {
    await seed(); // a, b, c cached
    await db.favoritesDao.add('a', at: DateTime(2026, 1, 2));
    await db.favoritesDao.add('z', at: DateTime(2026, 1, 3)); // not cached
    final favs = await db.indexDao.watchFavoritesInCache().first;
    expect(favs.map((f) => f.assetId).toList(), ['a']); // z (dangling) dropped
  });

  test('watchFavoritesInCache orders most-recently-favorited first', () async {
    await seed(); // a, b, c cached
    await db.favoritesDao.add('a', at: DateTime(2020, 1, 1));
    await db.favoritesDao.add('b', at: DateTime(2024, 1, 1));
    final favs = await db.indexDao.watchFavoritesInCache().first;
    expect(favs.map((f) => f.assetId).toList(), ['b', 'a']);
  });

  test('matches a label as a case-insensitive substring, newest first',
      () async {
    await seed();
    expect(await search('dog'), ['a', 'b']);
    expect(await search('DOG'), ['a', 'b']);
    expect(await search('gra'), ['a']); // "Grass"
    expect(await search('cat'), isEmpty);
  });

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
}
