// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'albums_dao.dart';

// ignore_for_file: type=lint
mixin _$AlbumsDaoMixin on DatabaseAccessor<AppDatabase> {
  $AlbumsTable get albums => attachedDatabase.albums;
  $AlbumEntriesTable get albumEntries => attachedDatabase.albumEntries;
  AlbumsDaoManager get managers => AlbumsDaoManager(this);
}

class AlbumsDaoManager {
  final _$AlbumsDaoMixin _db;
  AlbumsDaoManager(this._db);
  $$AlbumsTableTableManager get albums =>
      $$AlbumsTableTableManager(_db.attachedDatabase, _db.albums);
  $$AlbumEntriesTableTableManager get albumEntries =>
      $$AlbumEntriesTableTableManager(_db.attachedDatabase, _db.albumEntries);
}
