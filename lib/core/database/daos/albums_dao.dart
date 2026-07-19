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

  /// A single album by id, or null if it no longer exists. Backs the album
  /// detail app-bar title.
  Stream<Album?> watchAlbum(int albumId) {
    return (select(albums)..where((a) => a.id.equals(albumId)))
        .watchSingleOrNull();
  }

  /// Albums with their entry count and a representative cover asset id — the
  /// explicit [Albums.coverAssetId] if set, else the most recently added entry.
  /// Ordered like [watchAllAlbums]. Backs the Albums list grid.
  Stream<List<AlbumSummary>> watchAlbumSummaries() {
    final query = customSelect(
      'SELECT a.id AS id, a.name AS name, a.cover_asset_id AS cover_asset_id, '
      'COUNT(e.id) AS entry_count, '
      '(SELECT e2.asset_id FROM album_entries e2 WHERE e2.album_id = a.id '
      'ORDER BY e2.added_at DESC LIMIT 1) AS latest_asset_id '
      'FROM albums a '
      'LEFT JOIN album_entries e ON e.album_id = a.id '
      'GROUP BY a.id '
      'ORDER BY a.sort_index ASC, a.created_at ASC',
      readsFrom: {albums, albumEntries},
    );
    return query.watch().map(
          (rows) => rows
              .map((r) => AlbumSummary(
                    id: r.read<int>('id'),
                    name: r.read<String>('name'),
                    entryCount: r.read<int>('entry_count'),
                    coverAssetId: r.read<String?>('cover_asset_id') ??
                        r.read<String?>('latest_asset_id'),
                  ))
              .toList(),
        );
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

  /// Removes [assetId] from every album — used when the asset is deleted from
  /// the device library so no membership dangles. Returns rows deleted.
  Future<int> removeAssetEverywhere(String assetId) {
    return (delete(albumEntries)..where((e) => e.assetId.equals(assetId))).go();
  }
}

/// One row of the Albums list: an album plus its entry count and the cover
/// asset id to render (may be null for an empty album). Query DTO for
/// [AlbumsDao.watchAlbumSummaries] — not a persisted table.
class AlbumSummary {
  const AlbumSummary({
    required this.id,
    required this.name,
    required this.entryCount,
    required this.coverAssetId,
  });

  final int id;
  final String name;
  final int entryCount;
  final String? coverAssetId;
}
