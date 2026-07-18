// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'index_dao.dart';

// ignore_for_file: type=lint
mixin _$IndexDaoMixin on DatabaseAccessor<AppDatabase> {
  $PhotoAssetsTable get photoAssets => attachedDatabase.photoAssets;
  $PhotoLabelsTable get photoLabels => attachedDatabase.photoLabels;
  $PhotoTextsTable get photoTexts => attachedDatabase.photoTexts;
  $FavoritesTable get favorites => attachedDatabase.favorites;
  IndexDaoManager get managers => IndexDaoManager(this);
}

class IndexDaoManager {
  final _$IndexDaoMixin _db;
  IndexDaoManager(this._db);
  $$PhotoAssetsTableTableManager get photoAssets =>
      $$PhotoAssetsTableTableManager(_db.attachedDatabase, _db.photoAssets);
  $$PhotoLabelsTableTableManager get photoLabels =>
      $$PhotoLabelsTableTableManager(_db.attachedDatabase, _db.photoLabels);
  $$PhotoTextsTableTableManager get photoTexts =>
      $$PhotoTextsTableTableManager(_db.attachedDatabase, _db.photoTexts);
  $$FavoritesTableTableManager get favorites =>
      $$FavoritesTableTableManager(_db.attachedDatabase, _db.favorites);
}
