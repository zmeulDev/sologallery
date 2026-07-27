import 'package:drift/drift.dart';

import '../../../features/library/domain/year_month.dart';
import '../../../features/search/domain/search_date.dart';
import '../../../services/photo_library_service.dart' show AssetRef;
import '../app_database.dart';
import '../tables.dart';

part 'index_dao.g.dart';

/// The lean metadata the fast sweep caches per asset (no ML). [isDated] is false
/// only for Android undated assets (see [PhotoAssets.isDated]).
typedef SweptAsset = ({
  String id,
  DateTime createdAt,
  bool isVideo,
  int width,
  int height,
  bool isDated,
});

/// A favorited asset joined to its cached metadata — what the Saved grid needs
/// to lay itself out: the id to render, the timestamp it orders by, and the
/// dimensions its masonry columns are sized from.
typedef FavoriteAsset = ({
  String assetId,
  DateTime favoritedAt,
  int width,
  int height,
});

/// Data-access for the ML index: the [PhotoAssets] cache (metadata sweep +
/// indexing cursor), the [PhotoLabels] image labels, and the [PhotoTexts] OCR
/// text. Pure data layer — no UI, no ML. The background [IndexingService] sweeps
/// metadata and writes ML rows here; the Library/Saved grids and Search read.
@DriftAccessor(tables: [PhotoAssets, PhotoLabels, PhotoTexts, Favorites, RecentlyViewed])
class IndexDao extends DatabaseAccessor<AppDatabase> with _$IndexDaoMixin {
  IndexDao(super.db);

  // --- Metadata sweep ------------------------------------------------------

  /// Upserts lean metadata for [rows] (the fast sweep). New rows land with
  /// `indexedAt = NULL` (ML pending); existing rows keep their `indexedAt` and
  /// only refresh metadata — the [DoUpdate] deliberately omits `indexedAt` so an
  /// already-ML'd row is not reset to pending.
  Future<void> upsertMetadata(List<SweptAsset> rows) async {
    await batch((b) {
      for (final r in rows) {
        b.insert(
          photoAssets,
          PhotoAssetsCompanion.insert(
            assetId: r.id,
            createdAt: r.createdAt,
            isVideo: r.isVideo,
            width: r.width,
            height: r.height,
            isDated: Value(r.isDated),
          ),
          onConflict: DoUpdate(
            (_) => PhotoAssetsCompanion(
              createdAt: Value(r.createdAt),
              isVideo: Value(r.isVideo),
              width: Value(r.width),
              height: Value(r.height),
              isDated: Value(r.isDated),
            ),
          ),
        );
      }
    });
  }

  /// Whether the cached row for [assetId] is a video. False when the asset isn't
  /// cached yet — the grid badge just appears once the metadata sweep records it.
  /// An in-process lookup so [videoDurationProvider] can skip the platform
  /// round-trip for the overwhelming majority of cells (photos) — see B6.
  Future<bool> isVideoInCache(String assetId) async {
    final row = await (selectOnly(photoAssets)
          ..addColumns([photoAssets.isVideo])
          ..where(photoAssets.assetId.equals(assetId)))
        .map((r) => r.read(photoAssets.isVideo))
        .getSingleOrNull();
    return row ?? false;
  }

  /// Every cached asset id — the sweep subtracts the live library from this to
  /// find rows to prune (deleted assets / a shrunken limited-access subset).
  Future<Set<String>> allCachedIds() async {
    final rows =
        await (selectOnly(photoAssets)..addColumns([photoAssets.assetId]))
            .map((r) => r.read(photoAssets.assetId)!)
            .get();
    return rows.toSet();
  }

  /// Deletes cached rows for [ids] (pruned assets). Cascades remove their
  /// labels/OCR text/faces. No-op on an empty list.
  Future<int> deleteAssets(List<String> ids) async {
    if (ids.isEmpty) return 0;
    return (delete(photoAssets)..where((a) => a.assetId.isIn(ids))).go();
  }

  /// Wipes the whole `photo_asset` cache — cascades to labels, OCR text, and
  /// face embeddings. Backs Settings' "Rebuild index"; the caller re-sweeps
  /// afterwards. Persons are cleared separately (they are not FK-referenced by
  /// `photo_asset`) via `FacesDao.clearPersons`.
  Future<int> clearIndex() => delete(photoAssets).go();

  /// Deletes every derived label and OCR text, leaving the `photo_asset` cache
  /// (and so face embeddings) intact. Used when the user withdraws
  /// content-search consent — there is no asset wipe to cascade from.
  Future<void> clearContent() async {
    await delete(photoLabels).go();
    await delete(photoTexts).go();
  }

  /// Marks every cached asset as awaiting ML analysis again, without deleting
  /// the labels/OCR text already derived (`upsertIndexed` replaces those in
  /// place). Backs enabling face detection after the library was already
  /// indexed: those assets have `indexed_at` set, so [pendingMlIds] would
  /// otherwise never return them and their faces would never be computed.
  Future<int> resetMlPending() => update(
    photoAssets,
  ).write(const PhotoAssetsCompanion(indexedAt: Value(null)));

  /// Ids awaiting ML analysis (`indexed_at IS NULL`), newest first so recent
  /// photos are labelled first. Replaces the old indexed/library set-diff.
  Future<List<String>> pendingMlIds() {
    final q = selectOnly(photoAssets)
      ..addColumns([photoAssets.assetId])
      ..where(photoAssets.indexedAt.isNull())
      ..orderBy([OrderingTerm.desc(photoAssets.createdAt)]);
    return q.map((r) => r.read(photoAssets.assetId)!).get();
  }

  /// Cached-library totals for the Settings stats section, reactive: total
  /// photos+videos and how many of those are videos.
  Stream<({int photos, int videos})> watchLibraryTotals() {
    final total = photoAssets.assetId.count();
    final videos = photoAssets.assetId.count(
      filter: photoAssets.isVideo.equals(true),
    );
    final q = selectOnly(photoAssets)..addColumns([total, videos]);
    return q
        .map((r) => (photos: r.read(total) ?? 0, videos: r.read(videos) ?? 0))
        .watchSingle();
  }

  // --- ML results ----------------------------------------------------------

  /// Records that [assetId] has been ML-indexed: stamps `indexedAt`, refreshes
  /// its metadata (preserving `is_dated` from the sweep via [DoUpdate]), and
  /// replaces its label set + OCR text atomically.
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
      final now = DateTime.now();
      await into(photoAssets).insert(
        PhotoAssetsCompanion.insert(
          assetId: assetId,
          createdAt: createdAt,
          isVideo: isVideo,
          width: width,
          height: height,
          indexedAt: Value(now),
        ),
        onConflict: DoUpdate(
          (_) => PhotoAssetsCompanion(
            createdAt: Value(createdAt),
            isVideo: Value(isVideo),
            width: Value(width),
            height: Value(height),
            indexedAt: Value(now),
          ),
        ),
      );
      await (delete(photoLabels)..where((l) => l.assetId.equals(assetId))).go();
      // One batched insert for the whole label set, not N awaited inserts —
      // a typical asset carries 5–15 labels, so this turns tens of thousands
      // of round-trips across a full pass into thousands.
      if (labels.isNotEmpty) {
        await batch((b) {
          b.insertAll(
            photoLabels,
            [
              for (final (label, confidence) in labels)
                PhotoLabelsCompanion.insert(
                  assetId: assetId,
                  label: label,
                  confidence: confidence,
                ),
            ],
          );
        });
      }
      await (delete(photoTexts)..where((t) => t.assetId.equals(assetId))).go();
      if (text.isNotEmpty) {
        await into(
          photoTexts,
        ).insert(PhotoTextsCompanion.insert(assetId: assetId, content: text));
      }
    });
  }

  // --- Library grid (cache-backed) -----------------------------------------

  /// Non-empty calendar months over *dated* assets with their exact counts,
  /// newest first — one grouped query backing the Library home. Reactive: emits
  /// on every cache change (sweep, ML stamp, prune).
  Stream<List<({YearMonth month, int count})>> watchMonthCounts() {
    // Group by the *local* calendar month (`'localtime'`), matching
    // [YearMonth.fromDate] and [monthAssets]'s local `[start, end)` window.
    // Drift's `.month`/`.year` extract in UTC, which mis-buckets assets near a
    // month boundary in a non-UTC timezone. `created_at` is stored as unix
    // seconds (default int storage), so `'unixepoch'` applies. Key is
    // `YYYY-MM`, whose lexical order is chronological.
    final key = CustomExpression<String>(
      "STRFTIME('%Y-%m', created_at, 'unixepoch', 'localtime')",
      precedence: Precedence.primary,
    );
    final count = photoAssets.assetId.count();
    final q = selectOnly(photoAssets)
      ..addColumns([key, count])
      ..where(photoAssets.isDated.equals(true))
      ..groupBy([key])
      ..orderBy([OrderingTerm.desc(key)]);
    return q.map((r) {
      final parts = r.read(key)!.split('-');
      return (
        month: YearMonth(int.parse(parts[0]), int.parse(parts[1])),
        count: r.read(count)!,
      );
    }).watch();
  }

  /// Up to [limit] newest preview ids for a dated [month], reactive — re-emits
  /// as the sweep/ML/prune change the cache so the home section stays live.
  Stream<List<String>> watchMonthPreviews(YearMonth month, {int limit = 6}) {
    final q = selectOnly(photoAssets)
      ..addColumns([photoAssets.assetId])
      ..where(_datedInMonth(month))
      ..orderBy([OrderingTerm.desc(photoAssets.createdAt)])
      ..limit(limit);
    return q.map((r) => r.read(photoAssets.assetId)!).watch();
  }

  /// A page of dated asset refs for one [month]'s full grid, newest first.
  Future<List<AssetRef>> monthAssets(
    YearMonth month, {
    required int limit,
    required int offset,
  }) async {
    final q = select(photoAssets)
      ..where(
        (a) =>
            a.isDated.equals(true) &
            a.createdAt.isBiggerOrEqualValue(month.start) &
            a.createdAt.isSmallerThanValue(month.end),
      )
      ..orderBy([(a) => OrderingTerm.desc(a.createdAt)])
      ..limit(limit, offset: offset);
    final rows = await q.get();
    return [
      for (final r in rows) AssetRef(id: r.assetId, createdAt: r.createdAt),
    ];
  }

  /// The dated [month]'s full grid as a reactive growing window: the newest
  /// [limit] asset refs, re-emitting on any cache change. The paginator grows
  /// [limit] (offset stays 0) so a single live subscription covers all loaded
  /// pages.
  Stream<List<AssetRef>> watchMonthAssets(
    YearMonth month, {
    required int limit,
  }) {
    final q = select(photoAssets)
      ..where(
        (a) =>
            a.isDated.equals(true) &
            a.createdAt.isBiggerOrEqualValue(month.start) &
            a.createdAt.isSmallerThanValue(month.end),
      )
      ..orderBy([(a) => OrderingTerm.desc(a.createdAt)])
      ..limit(limit);
    return q.watch().map(
      (rows) => [
        for (final r in rows) AssetRef(id: r.assetId, createdAt: r.createdAt),
      ],
    );
  }

  // --- Year grouping (the `Year` / `Months` time filters) ------------------

  /// Non-empty calendar years over *dated* assets with their exact counts,
  /// newest first — the year-grouped mirror of [watchMonthCounts], and reactive
  /// on the same cache changes.
  Stream<List<({int year, int count})>> watchYearCounts() {
    // Local-time extraction, for the same reason [watchMonthCounts] does it:
    // Drift's `.year` extracts in UTC, which would file a local-Jan-1 00:00
    // capture under the previous year in any timezone west of UTC.
    final key = CustomExpression<String>(
      "STRFTIME('%Y', created_at, 'unixepoch', 'localtime')",
      precedence: Precedence.primary,
    );
    final count = photoAssets.assetId.count();
    final q = selectOnly(photoAssets)
      ..addColumns([key, count])
      ..where(photoAssets.isDated.equals(true))
      ..groupBy([key])
      ..orderBy([OrderingTerm.desc(key)]);
    return q
        .map((r) => (year: int.parse(r.read(key)!), count: r.read(count)!))
        .watch();
  }

  /// Up to [limit] newest preview ids for one calendar [year], reactive —
  /// the year-section mirror of [watchMonthPreviews].
  Stream<List<String>> watchYearPreviews(int year, {int limit = 6}) {
    final q = selectOnly(photoAssets)
      ..addColumns([photoAssets.assetId])
      ..where(
        photoAssets.isDated.equals(true) &
            photoAssets.createdAt.isBiggerOrEqualValue(DateTime(year)) &
            photoAssets.createdAt.isSmallerThanValue(DateTime(year + 1)),
      )
      ..orderBy([OrderingTerm.desc(photoAssets.createdAt)])
      ..limit(limit);
    return q.map((r) => r.read(photoAssets.assetId)!).watch();
  }

  /// A page of dated asset refs for one [year]'s full grid, newest first, as a
  /// reactive growing window — the year mirror of [watchMonthAssets].
  Stream<List<AssetRef>> watchYearAssets(int year, {required int limit}) {
    final q = select(photoAssets)
      ..where(
        (a) =>
            a.isDated.equals(true) &
            a.createdAt.isBiggerOrEqualValue(DateTime(year)) &
            a.createdAt.isSmallerThanValue(DateTime(year + 1)),
      )
      ..orderBy([(a) => OrderingTerm.desc(a.createdAt)])
      ..limit(limit);
    return q.watch().map(
      (rows) => [
        for (final r in rows) AssetRef(id: r.assetId, createdAt: r.createdAt),
      ],
    );
  }

  // --- Recent window (the `This week` time filter) --------------------------

  /// Dated asset refs captured on or after [cutoff], newest first, reactive.
  ///
  /// [limit] is a safety rail, not a page size — the caller shows the whole
  /// result as one scrolling grid, and a week's captures are small. A local
  /// `DateTime` maps to the same absolute instant the column stores, so the
  /// boundary lands on the caller's local midnight without a timezone dance.
  Stream<List<AssetRef>> watchRecentSince(DateTime cutoff, {int limit = 500}) {
    final q = select(photoAssets)
      ..where(
        (a) =>
            a.isDated.equals(true) & a.createdAt.isBiggerOrEqualValue(cutoff),
      )
      ..orderBy([(a) => OrderingTerm.desc(a.createdAt)])
      ..limit(limit);
    return q.watch().map(
      (rows) => [
        for (final r in rows) AssetRef(id: r.assetId, createdAt: r.createdAt),
      ],
    );
  }

  /// Non-empty calendar days over *dated* assets on or after [cutoff] with their
  /// exact counts, newest first. Groups by local calendar day, matching how
  /// [watchMonthCounts] groups by local month so a capture near midnight ends up
  /// in the day the user sees.
  Stream<List<({DateTime day, int count})>> watchDayCounts(DateTime cutoff) {
    final key = CustomExpression<String>(
      "STRFTIME('%Y-%m-%d', created_at, 'unixepoch', 'localtime')",
      precedence: Precedence.primary,
    );
    final count = photoAssets.assetId.count();
    final q = selectOnly(photoAssets)
      ..addColumns([key, count])
      ..where(photoAssets.isDated.equals(true) & photoAssets.createdAt.isBiggerOrEqualValue(cutoff))
      ..groupBy([key])
      ..orderBy([OrderingTerm.desc(key)]);
    return q.map((r) {
      final parts = r.read(key)!.split('-');
      return (
        day: DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        ),
        count: r.read(count)!,
      );
    }).watch();
  }

  /// Up to [limit] newest preview ids for one calendar [day], reactive — the
  /// day-section mirror of [watchMonthPreviews].
  Stream<List<String>> watchDayPreviews(DateTime day, {int limit = 6}) {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    final q = selectOnly(photoAssets)
      ..addColumns([photoAssets.assetId])
      ..where(
        photoAssets.isDated.equals(true) &
            photoAssets.createdAt.isBiggerOrEqualValue(start) &
            photoAssets.createdAt.isSmallerThanValue(end),
      )
      ..orderBy([OrderingTerm.desc(photoAssets.createdAt)])
      ..limit(limit);
    return q.map((r) => r.read(photoAssets.assetId)!).watch();
  }

  /// A page of dated asset refs for one calendar [day]'s full grid, newest
  /// first, as a reactive growing window — the day mirror of [watchMonthAssets].
  Stream<List<AssetRef>> watchDayAssets(DateTime day, {required int limit}) {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    final q = select(photoAssets)
      ..where(
        (a) =>
            a.isDated.equals(true) &
            a.createdAt.isBiggerOrEqualValue(start) &
            a.createdAt.isSmallerThanValue(end),
      )
      ..orderBy([(a) => OrderingTerm.desc(a.createdAt)])
      ..limit(limit);
    return q.watch().map(
      (rows) => [
        for (final r in rows) AssetRef(id: r.assetId, createdAt: r.createdAt),
      ],
    );
  }

  Expression<bool> _datedInMonth(YearMonth month) =>
      photoAssets.isDated.equals(true) &
      photoAssets.createdAt.isBiggerOrEqualValue(month.start) &
      photoAssets.createdAt.isSmallerThanValue(month.end);

  // --- "Older" bucket (undated; Android only) ------------------------------

  /// Count of undated assets, reactive. Zero (and empty grid) on iOS.
  Stream<int> watchOlderCount() {
    final count = photoAssets.assetId.count();
    final q = selectOnly(photoAssets)
      ..addColumns([count])
      ..where(photoAssets.isDated.equals(false));
    return q
        .map((r) => r.read(count) ?? 0)
        .watch()
        .map((rows) => rows.isEmpty ? 0 : rows.first);
  }

  /// Up to [limit] newest-added preview ids for the "Older" section, reactive.
  Stream<List<String>> watchOlderPreviews({int limit = 6}) {
    final q = selectOnly(photoAssets)
      ..addColumns([photoAssets.assetId])
      ..where(photoAssets.isDated.equals(false))
      ..orderBy([OrderingTerm.desc(photoAssets.createdAt)])
      ..limit(limit);
    return q.map((r) => r.read(photoAssets.assetId)!).watch();
  }

  /// The "Older" full grid as a reactive growing window — newest-added [limit]
  /// undated asset refs, re-emitting on any cache change.
  Stream<List<AssetRef>> watchOlderAssets({required int limit}) {
    final q = select(photoAssets)
      ..where((a) => a.isDated.equals(false))
      ..orderBy([(a) => OrderingTerm.desc(a.createdAt)])
      ..limit(limit);
    return q.watch().map(
      (rows) => [
        for (final r in rows) AssetRef(id: r.assetId, createdAt: r.createdAt),
      ],
    );
  }

  // --- Saved ---------------------------------------------------------------

  /// Favorites whose asset is still in the cache, most-recently-favorited first.
  /// The inner join drops dangling favorites (asset deleted / pruned) so the
  /// Saved grid never shows a broken thumbnail.
  ///
  /// Carries the cached pixel dimensions because the Saved grid is a masonry
  /// layout: it has to know each cell's aspect ratio *before* laying out, and
  /// the join it already does to prove the asset exists is exactly where those
  /// numbers live. Reading them from a decode instead would both cost a decode
  /// per cell and break the never-trust-Dart-decode-dimensions rule.
  Stream<List<FavoriteAsset>> watchFavoritesInCache() {
    final q = select(favorites).join([
      innerJoin(photoAssets, photoAssets.assetId.equalsExp(favorites.assetId)),
    ])..orderBy([OrderingTerm.desc(favorites.favoritedAt)]);
    return q.watch().map(
      (rows) => [
        for (final r in rows)
          (
            assetId: r.readTable(favorites).assetId,
            favoritedAt: r.readTable(favorites).favoritedAt,
            width: r.readTable(photoAssets).width,
            height: r.readTable(photoAssets).height,
          ),
      ],
    );
  }

  // --- Recently viewed -----------------------------------------------------

  /// Records that [assetId] was just viewed, moving it to the top of the
  /// Search "recently viewed" list. Upserts on [assetId] so re-viewing updates
  /// [viewedAt] rather than duplicating.
  Future<void> recordView(String assetId) async {
    await into(recentlyViewed).insertOnConflictUpdate(
      RecentlyViewedCompanion(
        assetId: Value(assetId),
        viewedAt: Value(DateTime.now()),
      ),
    );
  }

  /// The [limit] most recently viewed asset ids, newest first. Reactive: the
  /// Search strip updates as new views land.
  Stream<List<String>> watchRecentlyViewed({int limit = 12}) {
    final q = selectOnly(recentlyViewed)
      ..addColumns([recentlyViewed.assetId])
      ..orderBy([OrderingTerm.desc(recentlyViewed.viewedAt)])
      ..limit(limit);
    return q.map((r) => r.read(recentlyViewed.assetId)!).watch();
  }

  // --- Search --------------------------------------------------------------

  /// The [limit] most frequent labels in this library, restricted to [allow]
  /// (the curated browsable set) and ordered by how many assets carry them,
  /// ties alphabetical. Counts distinct assets, so a label the model emitted
  /// twice for one photo still counts once.
  ///
  /// Reactive: the Search browse chips grow into place as the background
  /// indexer labels more of the library, and a label nothing carries never
  /// appears — a chip that returns no photos is worse than no chip.
  Stream<List<({String label, int count})>> watchTopLabels({
    required Set<String> allow,
    int limit = 10,
  }) {
    // The aggregate has to be selected explicitly to be readable (CLAUDE.md).
    final count = photoLabels.assetId.count(distinct: true);
    final q = selectOnly(photoLabels)
      ..addColumns([photoLabels.label, count])
      ..where(photoLabels.label.isIn(allow.toList()))
      ..groupBy([photoLabels.label])
      ..orderBy([
        OrderingTerm.desc(count),
        OrderingTerm.asc(photoLabels.label),
      ])
      ..limit(limit);
    return q.watch().map(
      (rows) => [
        for (final r in rows)
          (label: r.read(photoLabels.label)!, count: r.read(count)!),
      ],
    );
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
      select(photoLabels)..where(
        (l) => l.assetId.equalsExp(photoAssets.assetId) & l.label.like(pattern),
      ),
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
