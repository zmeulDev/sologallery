import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/core/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('FavoritesDao', () {
    test('add then isFavorite reports true; remove reverts', () async {
      expect(await db.favoritesDao.isFavorite('asset-1'), isFalse);

      await db.favoritesDao.add('asset-1');
      expect(await db.favoritesDao.isFavorite('asset-1'), isTrue);

      final removed = await db.favoritesDao.remove('asset-1');
      expect(removed, 1);
      expect(await db.favoritesDao.isFavorite('asset-1'), isFalse);
    });

    test('add is idempotent (no duplicate primary key error)', () async {
      await db.favoritesDao.add('asset-1');
      await db.favoritesDao.add('asset-1');
      expect(await db.select(db.favorites).get(), hasLength(1));
    });

    test('remove is idempotent (returns 0 when absent)', () async {
      expect(await db.favoritesDao.remove('nope'), 0);
    });
  });

  group('AlbumsDao', () {
    test('createAlbum returns id and watchAllAlbums orders by sortIndex',
        () async {
      final first = await db.albumsDao.createAlbum('B');
      final second = await db.albumsDao.createAlbum('A');
      // Nudge the second album ahead via a lower sortIndex.
      await (db.update(db.albums)..where((a) => a.id.equals(second)))
          .write(const AlbumsCompanion(sortIndex: Value(-1)));

      final albums = await db.albumsDao.watchAllAlbums().first;
      expect(albums.first.id, second);
      expect(albums.map((a) => a.id), containsAll([first, second]));
    });

    test('addEntry is idempotent under UNIQUE(albumId, assetId)', () async {
      final album = await db.albumsDao.createAlbum('Trip');
      await db.albumsDao.addEntry(album, 'asset-1');
      await db.albumsDao.addEntry(album, 'asset-1'); // ignored
      final entries = await db.albumsDao.watchEntries(album).first;
      expect(entries, hasLength(1));
    });

    test('removeAssetEverywhere clears the asset from every album', () async {
      final trip = await db.albumsDao.createAlbum('Trip');
      final faves = await db.albumsDao.createAlbum('Faves');
      await db.albumsDao.addEntry(trip, 'asset-1');
      await db.albumsDao.addEntry(faves, 'asset-1');
      await db.albumsDao.addEntry(trip, 'asset-2');

      final removed = await db.albumsDao.removeAssetEverywhere('asset-1');
      expect(removed, 2);

      // asset-1 gone from both albums; asset-2 untouched.
      expect(await db.albumsDao.watchEntries(trip).first, hasLength(1));
      expect(await db.albumsDao.watchEntries(faves).first, isEmpty);
      final survivors = await db.select(db.albumEntries).get();
      expect(survivors.map((e) => e.assetId), ['asset-2']);
    });

    test('deleting an album cascades to its entries (FK pragma is on)',
        () async {
      final album = await db.albumsDao.createAlbum('Trip');
      await db.albumsDao.addEntry(album, 'asset-1');
      await db.albumsDao.addEntry(album, 'asset-2');

      await db.albumsDao.deleteAlbum(album);

      // Query the entries table directly — cascade must have removed them.
      final orphans = await db.select(db.albumEntries).get();
      expect(orphans, isEmpty);
    });

    test('watchAlbum returns the row, then null once deleted', () async {
      final id = await db.albumsDao.createAlbum('Trip');
      expect((await db.albumsDao.watchAlbum(id).first)?.name, 'Trip');

      await db.albumsDao.deleteAlbum(id);
      expect(await db.albumsDao.watchAlbum(id).first, isNull);
    });

    test('watchAlbumSummaries counts entries and picks the newest as cover',
        () async {
      final id = await db.albumsDao.createAlbum('Trip');
      await db.albumsDao.addEntry(id, 'old', at: DateTime(2020, 1, 1));
      await db.albumsDao.addEntry(id, 'new', at: DateTime(2024, 1, 1));

      final summaries = await db.albumsDao.watchAlbumSummaries().first;
      expect(summaries, hasLength(1));
      expect(summaries.single.entryCount, 2);
      // Cover falls back to the most recently added entry.
      expect(summaries.single.coverAssetId, 'new');
    });

    test('watchAlbumSummaries prefers an explicit coverAssetId', () async {
      final id = await db.albumsDao.createAlbum('Trip', coverAssetId: 'chosen');
      await db.albumsDao.addEntry(id, 'other', at: DateTime(2024, 1, 1));

      final summaries = await db.albumsDao.watchAlbumSummaries().first;
      expect(summaries.single.coverAssetId, 'chosen');
    });

    test('watchAlbumSummaries includes empty albums with a null cover',
        () async {
      await db.albumsDao.createAlbum('Empty');

      final summaries = await db.albumsDao.watchAlbumSummaries().first;
      expect(summaries.single.entryCount, 0);
      expect(summaries.single.coverAssetId, isNull);
    });

    test('watchAlbumSummaries orders by sortIndex then creation', () async {
      final b = await db.albumsDao.createAlbum('B');
      final a = await db.albumsDao.createAlbum('A');
      await (db.update(db.albums)..where((row) => row.id.equals(a)))
          .write(const AlbumsCompanion(sortIndex: Value(-1)));

      final summaries = await db.albumsDao.watchAlbumSummaries().first;
      expect(summaries.map((s) => s.id).toList(), [a, b]);
    });
  });

  group('EditInstructionsDao', () {
    test('upsert then getForAsset round-trips the JSON', () async {
      expect(await db.editInstructionsDao.getForAsset('asset-1'), isNull);

      await db.editInstructionsDao.upsert('asset-1', '{"rotate":90}');
      final row = await db.editInstructionsDao.getForAsset('asset-1');
      expect(row, isNotNull);
      expect(row!.instructionsJson, '{"rotate":90}');
    });

    test('upsert replaces the existing document', () async {
      await db.editInstructionsDao.upsert('asset-1', '{"rotate":90}');
      await db.editInstructionsDao.upsert('asset-1', '{"rotate":180}');
      final row = await db.editInstructionsDao.getForAsset('asset-1');
      expect(row!.instructionsJson, '{"rotate":180}');
    });

    test('deleteForAsset removes the document', () async {
      await db.editInstructionsDao.upsert('asset-1', '{}');
      final removed = await db.editInstructionsDao.deleteForAsset('asset-1');
      expect(removed, 1);
      expect(await db.editInstructionsDao.getForAsset('asset-1'), isNull);
    });
  });
}
