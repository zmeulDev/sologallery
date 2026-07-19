// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'memories_dao.dart';

// ignore_for_file: type=lint
mixin _$MemoriesDaoMixin on DatabaseAccessor<AppDatabase> {
  $PhotoAssetsTable get photoAssets => attachedDatabase.photoAssets;
  $MemoriesTable get memories => attachedDatabase.memories;
  $MemoryEntriesTable get memoryEntries => attachedDatabase.memoryEntries;
  $PhotoLabelsTable get photoLabels => attachedDatabase.photoLabels;
  MemoriesDaoManager get managers => MemoriesDaoManager(this);
}

class MemoriesDaoManager {
  final _$MemoriesDaoMixin _db;
  MemoriesDaoManager(this._db);
  $$PhotoAssetsTableTableManager get photoAssets =>
      $$PhotoAssetsTableTableManager(_db.attachedDatabase, _db.photoAssets);
  $$MemoriesTableTableManager get memories =>
      $$MemoriesTableTableManager(_db.attachedDatabase, _db.memories);
  $$MemoryEntriesTableTableManager get memoryEntries =>
      $$MemoryEntriesTableTableManager(_db.attachedDatabase, _db.memoryEntries);
  $$PhotoLabelsTableTableManager get photoLabels =>
      $$PhotoLabelsTableTableManager(_db.attachedDatabase, _db.photoLabels);
}
