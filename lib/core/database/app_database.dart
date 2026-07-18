import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'daos/albums_dao.dart';
import 'daos/edit_instructions_dao.dart';
import 'daos/faces_dao.dart';
import 'daos/favorites_dao.dart';
import 'daos/index_dao.dart';
import 'tables.dart';

part 'app_database.g.dart';

/// The app's local SQLite database (Drift).
///
/// 100% on-device — no network, no cloud sync (Absolute rules). Schema is
/// versioned; every upgrade path is covered by a `SchemaVerifier` migration
/// test (see docs/spec.md#data-model and test/core/database/).
///
/// v1 holds only user-authored state that must exist before ML indexing:
/// favorites, albums + membership, and non-destructive edit instructions.
///
/// v2 adds the ML/indexing tables `photo_asset` (indexing cursor + lean cached
/// metadata) and `photo_label` (on-device ML Kit image labels).
///
/// v3 adds `photo_text` (on-device OCR) plus `persons` + `face_embedding`
/// (on-device face clustering / people).
@DriftDatabase(
  tables: [
    Favorites,
    Albums,
    AlbumEntries,
    EditInstructions,
    PhotoAssets,
    PhotoLabels,
    PhotoTexts,
    Persons,
    FaceEmbeddings,
  ],
  daos: [FavoritesDao, AlbumsDao, EditInstructionsDao, IndexDao, FacesDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(photoAssets);
            await m.createTable(photoLabels);
            await m.create(photoLabelAsset);
            await m.create(photoLabelLabel);
          }
          if (from < 3) {
            await m.createTable(photoTexts);
            await m.createTable(persons);
            await m.createTable(faceEmbeddings);
            await m.create(faceAsset);
            await m.create(facePerson);
          }
        },
        beforeOpen: (details) async {
          // Foreign keys are OFF by default in SQLite; enable per-connection
          // so AlbumEntries cascade-on-album-delete (and photo_label cascade)
          // actually fire.
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'sologallery');
  }
}
