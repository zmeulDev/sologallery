// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'faces_dao.dart';

// ignore_for_file: type=lint
mixin _$FacesDaoMixin on DatabaseAccessor<AppDatabase> {
  $PersonsTable get persons => attachedDatabase.persons;
  $PhotoAssetsTable get photoAssets => attachedDatabase.photoAssets;
  $FaceEmbeddingsTable get faceEmbeddings => attachedDatabase.faceEmbeddings;
  FacesDaoManager get managers => FacesDaoManager(this);
}

class FacesDaoManager {
  final _$FacesDaoMixin _db;
  FacesDaoManager(this._db);
  $$PersonsTableTableManager get persons =>
      $$PersonsTableTableManager(_db.attachedDatabase, _db.persons);
  $$PhotoAssetsTableTableManager get photoAssets =>
      $$PhotoAssetsTableTableManager(_db.attachedDatabase, _db.photoAssets);
  $$FaceEmbeddingsTableTableManager get faceEmbeddings =>
      $$FaceEmbeddingsTableTableManager(
        _db.attachedDatabase,
        _db.faceEmbeddings,
      );
}
