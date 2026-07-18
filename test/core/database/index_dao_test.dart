import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/core/database/app_database.dart';
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

  test('indexedAssetIds returns every indexed asset', () async {
    await seed();
    expect(await db.indexDao.indexedAssetIds(), {'a', 'b', 'c'});
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
