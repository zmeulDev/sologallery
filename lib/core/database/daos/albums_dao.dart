import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'albums_dao.g.dart';

/// Data-access for [Albums] and their [AlbumEntries]. Pure data layer.
@DriftAccessor(tables: [Albums, AlbumEntries])
class AlbumsDao extends DatabaseAccessor<AppDatabase> with _$AlbumsDaoMixin {
  AlbumsDao(super.db);

  /// All albums, ordered by [Albums.sortIndex] then creation time.
  Stream<List<Album>> watchAllAlbums() {
    return (select(albums)
          ..orderBy([
            (a) => OrderingTerm.asc(a.sortIndex),
            (a) => OrderingTerm.asc(a.createdAt),
          ]))
        .watch();
  }

  /// Creates an album and returns its generated id.
  Future<int> createAlbum(String name, {String? coverAssetId, DateTime? at}) {
    return into(albums).insert(
      AlbumsCompanion.insert(
        name: name,
        coverAssetId: Value(coverAssetId),
        createdAt: at ?? DateTime.now(),
      ),
    );
  }

  /// Deletes an album; entries cascade via the foreign key.
  Future<int> deleteAlbum(int albumId) {
    return (delete(albums)..where((a) => a.id.equals(albumId))).go();
  }

  /// Entries of [albumId], most recently added first.
  Stream<List<AlbumEntry>> watchEntries(int albumId) {
    return (select(albumEntries)
          ..where((e) => e.albumId.equals(albumId))
          ..orderBy([(e) => OrderingTerm.desc(e.addedAt)]))
        .watch();
  }

  /// Adds a photo to an album (idempotent via the UNIQUE(album, asset) key).
  Future<void> addEntry(int albumId, String assetId, {DateTime? at}) {
    return into(albumEntries).insert(
      AlbumEntriesCompanion.insert(
        albumId: albumId,
        assetId: assetId,
        addedAt: at ?? DateTime.now(),
      ),
      mode: InsertMode.insertOrIgnore,
    );
  }

  /// Removes a photo from an album. Returns rows deleted.
  Future<int> removeEntry(int albumId, String assetId) {
    return (delete(albumEntries)
          ..where((e) => e.albumId.equals(albumId) & e.assetId.equals(assetId)))
        .go();
  }
}
