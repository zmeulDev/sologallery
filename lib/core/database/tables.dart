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

/// Generic key/value app preferences (theme override, and future prefs). One
/// row per setting; both columns are plain text — callers encode/decode typed
/// values (see [SettingsDao]). Persisted in Drift per the "Drift for all
/// persistence" rule (never `shared_preferences`).
class AppSettings extends Table {
  /// Stable setting key (e.g. `theme_mode`).
  TextColumn get key => text()();

  /// Serialized value.
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

/// One row per asset that the background indexer has processed — the indexing
/// cursor and a small cached-metadata table (docs/spec.md#data-model, ML phase).
/// A row's presence means "already indexed"; the orchestrator subtracts these
/// ids from the library to find remaining work. Kept lean: only the fields
/// indexing and label search consume today (GPS/modified/duration deferred until
/// a consumer needs them). Keyed by `photo_manager` asset id.
class PhotoAssets extends Table {
  /// `photo_manager` asset id.
  TextColumn get assetId => text()();

  /// Capture date (the axis the grid orders/groups by); mirrors
  /// `AssetRef.createdAt`.
  DateTimeColumn get createdAt => dateTime()();

  BoolColumn get isVideo => boolean()();

  IntColumn get width => integer()();

  IntColumn get height => integer()();

  /// Whether this asset has a real capture date (the axis the grid groups by).
  /// `false` only for Android *undated* assets, whose [createdAt] is a
  /// `DATE_ADDED` fallback — they surface in the trailing "Older" bucket instead
  /// of a calendar month. Always `true` on iOS (`creationDate` is always present).
  BoolColumn get isDated => boolean().withDefault(const Constant(true))();

  /// When ML indexing (labels/OCR/faces) last completed for this asset. `NULL`
  /// means the fast metadata sweep has cached the row but ML has not run yet —
  /// the background indexer's remaining work is exactly the `NULL` rows.
  DateTimeColumn get indexedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {assetId};
}

/// On-device ML Kit image labels, one row per (asset, label). Deleting the
/// [PhotoAssets] row cascades to its labels (re-index replaces cleanly). Indexed
/// on `assetId` (grouping) and `label` (search `LIKE`).
@TableIndex(name: 'photo_label_asset', columns: {#assetId})
@TableIndex(name: 'photo_label_label', columns: {#label})
class PhotoLabels extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// `photo_manager` asset id; cascades from [PhotoAssets].
  TextColumn get assetId =>
      text().references(PhotoAssets, #assetId, onDelete: KeyAction.cascade)();

  /// The ML Kit label text (e.g. "Dog"), stored as returned.
  TextColumn get label => text()();

  /// Model confidence in `[0, 1]`.
  RealColumn get confidence => real()();
}

/// On-device OCR text for an asset — one row per asset holding the concatenated
/// recognized text (ML Kit text recognition, bundled Latin model). Empty when
/// no text was found. Cascades from [PhotoAssets]; matched by `LIKE` in Search.
class PhotoTexts extends Table {
  /// `photo_manager` asset id; cascades from [PhotoAssets].
  TextColumn get assetId =>
      text().references(PhotoAssets, #assetId, onDelete: KeyAction.cascade)();

  /// The recognized text, newlines collapsed to spaces. Named `content` (not
  /// `text`) — a drift column can't reuse the `text()` builder name.
  TextColumn get content => text()();

  @override
  Set<Column> get primaryKey => {assetId};
}

/// A clustered person — a group of face embeddings the on-device clustering
/// decided are the same individual. [displayName] is user-set (null = unnamed);
/// [coverAssetId] is a representative photo for the avatar.
class Persons extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get displayName => text().nullable()();

  /// A `photo_manager` asset id used for the person's cover/avatar.
  TextColumn get coverAssetId => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();
}

/// An auto-curated "memory" — a titled collection the app generates from
/// indexed metadata (date, ML labels, clustered people). Never user-authored:
/// the background indexer rebuilds these from [PlannedMemory] plans.
///
/// [sourceKey] is the idempotence key (`otd:07-19:2024`, `trip:2025-06-01`,
/// `theme:dog`, `person:3`). Regeneration upserts on it rather than wiping the
/// table, so [seenAt] / [hidden] survive and the carousel never reshuffles
/// under the user.
///
/// [coverAssetId] is `setNull` (not cascade) — deleting the cover photo must
/// not delete the memory; a memory whose *entries* fall below its type's
/// minimum is pruned by the next regeneration instead.
class Memories extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Stable regeneration key; see class docs.
  TextColumn get sourceKey => text().unique()();

  /// `MemoryKind.name`.
  TextColumn get kind => text()();

  TextColumn get title => text()();

  TextColumn get subtitle => text().nullable()();

  /// A `photo_manager` asset id used for the card cover.
  TextColumn get coverAssetId => text()
      .nullable()
      .references(PhotoAssets, #assetId, onDelete: KeyAction.setNull)();

  /// Carousel ordering weight, descending. Named `score` rather than `rank`
  /// to stay clear of SQL's window-function name.
  RealColumn get score => real()();

  /// Optional display window — an "On this day" memory stops surfacing once
  /// [periodEnd] has passed. NULL on both = always eligible.
  DateTimeColumn get periodStart => dateTime().nullable()();

  DateTimeColumn get periodEnd => dateTime().nullable()();

  DateTimeColumn get generatedAt => dateTime()();

  /// When the user first opened this memory (NULL = unseen).
  DateTimeColumn get seenAt => dateTime().nullable()();

  /// User-dismissed; excluded from the carousel but kept so regeneration
  /// doesn't resurrect it.
  BoolColumn get hidden => boolean().withDefault(const Constant(false))();
}

/// Ordered membership of a [Memories] row. Cascades from both sides: deleting
/// the memory drops its entries, and deleting the underlying photo drops the
/// entry (so memories self-heal as the library changes).
@TableIndex(name: 'memory_entry_memory', columns: {#memoryId})
class MemoryEntries extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get memoryId =>
      integer().references(Memories, #id, onDelete: KeyAction.cascade)();

  /// `photo_manager` asset id; cascades from [PhotoAssets].
  TextColumn get assetId =>
      text().references(PhotoAssets, #assetId, onDelete: KeyAction.cascade)();

  /// Playback order within the memory, ascending (oldest first — a story
  /// reads forward in time).
  IntColumn get position => integer()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {memoryId, assetId},
      ];
}

/// One detected face: its on-device embedding vector plus the bounding box.
/// [personId] is the cluster it was assigned to (null until clustered).
/// Cascades from [PhotoAssets]; a deleted [Persons] row nulls the link (faces
/// survive re-clustering).
///
/// The box is stored **normalized to `[0, 1]`** against the analysis
/// thumbnail's real decoded width/height — a *fraction* of the image, not
/// pixels. Pixels were tried first (v3–v6) and were wrong: they only mean
/// something alongside the exact thumbnail dimensions they were measured
/// against, which were never recorded, so the avatar had to guess them from a
/// `512` constant. `photo_manager`'s `thumbnail(id, 512, 512)` returns an
/// aspect-**fill** image (short edge 512, long edge larger — a 4:3 photo comes
/// back 683×512), so that guess was off by the aspect ratio and every avatar
/// cropped ~33% too large and down-and-right of the face. Fractions need no
/// such guess: multiply by whatever image is on screen.
@TableIndex(name: 'face_asset', columns: {#assetId})
@TableIndex(name: 'face_person', columns: {#personId})
class FaceEmbeddings extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// `photo_manager` asset id; cascades from [PhotoAssets].
  TextColumn get assetId =>
      text().references(PhotoAssets, #assetId, onDelete: KeyAction.cascade)();

  IntColumn get personId =>
      integer().nullable().references(Persons, #id, onDelete: KeyAction.setNull)();

  /// The face-embedding vector, `Float32List` bytes (little-endian).
  BlobColumn get embedding => blob()();

  /// Box edges as fractions of the image's width/height, in `[0, 1]`.
  RealColumn get left => real()();
  RealColumn get top => real()();
  RealColumn get right => real()();
  RealColumn get bottom => real()();
}
