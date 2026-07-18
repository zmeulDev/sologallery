import 'package:drift/drift.dart';

import '../../../features/search/domain/search_date.dart';
import '../../../services/photo_library_service.dart' show AssetRef;
import '../app_database.dart';
import '../tables.dart';

part 'index_dao.g.dart';

/// Data-access for the ML index: the [PhotoAssets] cursor/metadata cache, the
/// [PhotoLabels] image labels, and the [PhotoTexts] OCR text. Pure data layer —
/// no UI, no ML. The background [IndexingService] writes here; Search reads via
/// [searchContent].
@DriftAccessor(tables: [PhotoAssets, PhotoLabels, PhotoTexts, Favorites])
class IndexDao extends DatabaseAccessor<AppDatabase> with _$IndexDaoMixin {
  IndexDao(super.db);

  /// Ids of every already-indexed asset — the orchestrator subtracts these from
  /// the library to find remaining work.
  Future<Set<String>> indexedAssetIds() async {
    final rows = await (selectOnly(photoAssets)..addColumns([photoAssets.assetId]))
        .map((r) => r.read(photoAssets.assetId)!)
        .get();
    return rows.toSet();
  }

  /// Records that [assetId] has been indexed: upserts its metadata row and
  /// replaces its label set + OCR text atomically (re-index safe; old rows are
  /// deleted explicitly since the metadata row is updated in place).
  Future<void> upsertIndexed({
    required String assetId,
    required DateTime createdAt,
    required bool isVideo,
    required int width,
    required int height,
    required List<(String label, double confidence)> labels,
    required String text,
  }) async {
    await transaction(() async {
      await into(photoAssets).insertOnConflictUpdate(
        PhotoAssetsCompanion.insert(
          assetId: assetId,
          createdAt: createdAt,
          isVideo: isVideo,
          width: width,
          height: height,
          indexedAt: DateTime.now(),
        ),
      );
      await (delete(photoLabels)..where((l) => l.assetId.equals(assetId))).go();
      for (final (label, confidence) in labels) {
        await into(photoLabels).insert(
          PhotoLabelsCompanion.insert(
            assetId: assetId,
            label: label,
            confidence: confidence,
          ),
        );
      }
      await (delete(photoTexts)..where((t) => t.assetId.equals(assetId))).go();
      if (text.isNotEmpty) {
        await into(photoTexts).insert(
          PhotoTextsCompanion.insert(assetId: assetId, content: text),
        );
      }
    });
  }

  /// Assets whose ML labels **or** OCR text match [query] (case-insensitive
  /// substring), newest first, refined by the same facets as metadata Search:
  /// capture-date window `[min, max)`, media [type], and (when [favoritesOnly])
  /// the favorites set. Paginated with [limit]/[offset]. One [AssetRef] per
  /// asset — the base row is `photo_asset`, so no dedupe is needed.
  Future<List<AssetRef>> searchContent({
    required String query,
    DateTime? min,
    DateTime? max,
    required MediaTypeFilter type,
    required bool favoritesOnly,
    required int limit,
    required int offset,
  }) async {
    // SQLite LIKE is case-insensitive for ASCII; labels/text are plain words.
    final pattern = '%$query%';
    final labelMatch = existsQuery(
      select(photoLabels)
        ..where((l) =>
            l.assetId.equalsExp(photoAssets.assetId) & l.label.like(pattern)),
    );

    final q = select(photoAssets).join([
      leftOuterJoin(
        photoTexts,
        photoTexts.assetId.equalsExp(photoAssets.assetId),
      ),
      if (favoritesOnly)
        innerJoin(favorites, favorites.assetId.equalsExp(photoAssets.assetId)),
    ]);

    q.where(labelMatch | photoTexts.content.like(pattern));
    if (min != null) {
      q.where(photoAssets.createdAt.isBiggerOrEqualValue(min));
    }
    if (max != null) {
      q.where(photoAssets.createdAt.isSmallerThanValue(max));
    }
    switch (type) {
      case MediaTypeFilter.all:
        break;
      case MediaTypeFilter.photos:
        q.where(photoAssets.isVideo.equals(false));
      case MediaTypeFilter.videos:
        q.where(photoAssets.isVideo.equals(true));
    }

    q
      ..orderBy([OrderingTerm.desc(photoAssets.createdAt)])
      ..limit(limit, offset: offset);

    final rows = await q.get();
    return [
      for (final r in rows)
        AssetRef(
          id: r.readTable(photoAssets).assetId,
          createdAt: r.readTable(photoAssets).createdAt,
        ),
    ];
  }
}
