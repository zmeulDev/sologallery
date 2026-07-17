import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'daos/albums_dao.dart';
import 'daos/edit_instructions_dao.dart';
import 'daos/favorites_dao.dart';
import 'tables.dart';

part 'app_database.g.dart';

/// The app's local SQLite database (Drift).
///
/// 100% on-device — no network, no cloud sync (Absolute rules). Schema is
/// versioned; every upgrade path is covered by a `SchemaVerifier` migration
/// test (see docs/spec.md#data-model and test/core/database/).
///
/// v1 holds only user-authored state that must exist before ML indexing:
/// favorites, albums + membership, and non-destructive edit instructions. The
/// ML/indexing tables (photo_asset, photo_label, face_embedding) arrive in a
/// later schema version.
@DriftDatabase(
  tables: [Favorites, Albums, AlbumEntries, EditInstructions],
  daos: [FavoritesDao, AlbumsDao, EditInstructionsDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        beforeOpen: (details) async {
          // Foreign keys are OFF by default in SQLite; enable per-connection
          // so AlbumEntries cascade-on-album-delete actually fires.
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'sologallery');
  }
}
