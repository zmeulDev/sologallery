import 'package:drift/drift.dart';

/// Photos the user has marked as favorite.
///
/// Keyed by the `photo_manager` asset id (a stable string), NOT a foreign key
/// into an indexed-asset table — favorites must work before ML indexing
/// populates any asset cache. See docs/spec.md#data-model.
class Favorites extends Table {
  /// `photo_manager` asset id.
  TextColumn get assetId => text()();

  DateTimeColumn get favoritedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {assetId};
}

/// User-created albums. Membership lives in [AlbumEntries] as asset-id
/// references — originals are never copied (Absolute rule: never duplicate
/// photos).
class Albums extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text().withLength(min: 1, max: 200)();

  /// Optional cover; a `photo_manager` asset id.
  TextColumn get coverAssetId => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  IntColumn get sortIndex => integer().withDefault(const Constant(0))();
}

/// Join between an [Albums] row and a photo (by asset id). Deleting an album
/// cascades to its entries.
class AlbumEntries extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get albumId =>
      integer().references(Albums, #id, onDelete: KeyAction.cascade)();

  /// `photo_manager` asset id.
  TextColumn get assetId => text()();

  DateTimeColumn get addedAt => dateTime()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {albumId, assetId},
      ];
}

/// Non-destructive edit instructions, one row per photo. Originals are never
/// modified; edits are stored as a JSON instruction blob (Absolute rule:
/// non-destructive edits only). See docs/spec.md#data-model.
class EditInstructions extends Table {
  /// `photo_manager` asset id.
  TextColumn get assetId => text()();

  /// Serialized edit instruction document.
  TextColumn get instructionsJson => text()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {assetId};
}
