import 'package:drift/drift.dart';

import '../../../features/memories/domain/planned_memory.dart';
import '../../../services/photo_library_service.dart' show AssetRef;
import '../app_database.dart';
import '../tables.dart';

part 'memories_dao.g.dart';

/// A memory as the carousel renders it: identity, copy, cover, and how many
/// photos it holds.
class MemorySummary {
  const MemorySummary({
    required this.id,
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.coverAssetId,
    required this.assetCount,
  });

  final int id;

  /// `MemoryKind.name` as persisted.
  final String kind;

  final String title;
  final String? subtitle;
  final String? coverAssetId;
  final int assetCount;
}

/// A label and how many distinct assets carry it above the confidence floor.
typedef LabelTally = ({String label, int assetCount});

/// Data-access for auto-curated memories. Pure data layer — the *decision* of
/// which memories exist lives in `memory_builder.dart`; this fetches the thin
/// projections that feed it, persists the resulting plan, and serves the UI.
///
/// Mirrors `FacesDao.rebuildClusters`: the background indexer plans, the DAO
/// applies.
@DriftAccessor(
  tables: [Memories, MemoryEntries, PhotoAssets, PhotoLabels],
)
class MemoriesDao extends DatabaseAccessor<AppDatabase>
    with _$MemoriesDaoMixin {
  MemoriesDao(super.db);

  /// Labels below this confidence never inform a memory.
  static const labelConfidenceFloor = 0.7;

  // --- Read side (UI) ------------------------------------------------------

  /// Memories eligible for the carousel right now, best first.
  ///
  /// Excludes dismissed rows and any whose display window has closed (an
  /// "On this day" memory stops surfacing at midnight). Reactive — emits on
  /// every regeneration.
  Stream<List<MemorySummary>> watchActive({int limit = 10, DateTime? now}) {
    final at = now ?? DateTime.now();
    final count = memoryEntries.id.count();
    final q = select(memories).join([
      innerJoin(memoryEntries, memoryEntries.memoryId.equalsExp(memories.id)),
    ])
      // The aggregate must be in the selected columns or `row.read` throws.
      ..addColumns([count])
      ..where(
        memories.hidden.equals(false) &
            (memories.periodEnd.isNull() |
                memories.periodEnd.isBiggerThanValue(at)) &
            (memories.periodStart.isNull() |
                memories.periodStart.isSmallerOrEqualValue(at)),
      )
      ..groupBy([memories.id])
      ..orderBy([OrderingTerm.desc(memories.score)])
      ..limit(limit);

    return q.watch().map((rows) => [
          for (final r in rows)
            MemorySummary(
              id: r.readTable(memories).id,
              kind: r.readTable(memories).kind,
              title: r.readTable(memories).title,
              subtitle: r.readTable(memories).subtitle,
              coverAssetId: r.readTable(memories).coverAssetId,
              assetCount: r.read(count)!,
            ),
        ]);
  }

  /// A single memory row (null once regeneration prunes it).
  Future<Memory?> memoryById(int id) =>
      (select(memories)..where((m) => m.id.equals(id))).getSingleOrNull();

  /// The memory's photos in playback order (oldest first). Bounded by
  /// `MemoryBuilder.maxAssetsPerMemory`, so this is deliberately un-paged.
  Future<List<AssetRef>> assetsFor(int memoryId) async {
    final q = select(memoryEntries).join([
      innerJoin(
        photoAssets,
        photoAssets.assetId.equalsExp(memoryEntries.assetId),
      ),
    ])
      ..where(memoryEntries.memoryId.equals(memoryId))
      ..orderBy([OrderingTerm.asc(memoryEntries.position)]);
    final rows = await q.get();
    return [
      for (final r in rows)
        AssetRef(
          id: r.readTable(photoAssets).assetId,
          createdAt: r.readTable(photoAssets).createdAt,
        ),
    ];
  }

  /// Stamps a memory as opened. Preserved across regeneration (upsert by
  /// `sourceKey` never touches this column).
  Future<void> markSeen(int id) =>
      (update(memories)..where((m) => m.id.equals(id)))
          .write(MemoriesCompanion(seenAt: Value(DateTime.now())));

  /// User-dismissed: drops out of the carousel without being resurrected by
  /// the next regeneration.
  Future<void> hide(int id) =>
      (update(memories)..where((m) => m.id.equals(id)))
          .write(const MemoriesCompanion(hidden: Value(true)));

  /// Wipes every memory — used by Settings' "Rebuild index", which clears the
  /// `photo_asset` cache the plans are derived from.
  Future<int> clearMemories() => delete(memories).go();

  // --- Generation inputs (background) --------------------------------------

  /// Dated assets sharing [month]/[day] in the **local** calendar, newest
  /// first — the "On this day" candidate pool across all years.
  ///
  /// Matches on a `'localtime'` `STRFTIME`, not Drift's `.month`/`.day`, which
  /// extract in UTC and would pull in neighbouring days in any non-UTC zone.
  Future<List<DatedAsset>> onThisDay(int month, int day) async {
    final mmdd = '${month.toString().padLeft(2, '0')}-'
        '${day.toString().padLeft(2, '0')}';
    final key = CustomExpression<String>(
      "STRFTIME('%m-%d', created_at, 'unixepoch', 'localtime')",
      precedence: Precedence.primary,
    );
    final q = selectOnly(photoAssets)
      ..addColumns([photoAssets.assetId, photoAssets.createdAt])
      ..where(photoAssets.isDated.equals(true) & key.equals(mmdd))
      ..orderBy([OrderingTerm.desc(photoAssets.createdAt)]);
    return [
      for (final r in await q.get())
        (
          assetId: r.read(photoAssets.assetId)!,
          createdAt: r.read(photoAssets.createdAt)!,
        ),
    ];
  }

  /// A thin `(id, createdAt)` projection of the newest dated assets — the
  /// input to trip clustering. Bounded on purpose: full rows over a large
  /// library would be wasteful, and the caller chunks its scan of this.
  Future<List<DatedAsset>> recentDatedProjection({int limit = 20000}) async {
    final q = selectOnly(photoAssets)
      ..addColumns([photoAssets.assetId, photoAssets.createdAt])
      ..where(photoAssets.isDated.equals(true))
      ..orderBy([OrderingTerm.desc(photoAssets.createdAt)])
      ..limit(limit);
    return [
      for (final r in await q.get())
        (
          assetId: r.read(photoAssets.assetId)!,
          createdAt: r.read(photoAssets.createdAt)!,
        ),
    ];
  }

  /// How many assets the cache holds — the indexer's signal for when enough
  /// new photos have accrued to justify regenerating.
  Future<int> cachedAssetCount() async {
    final c = photoAssets.assetId.count();
    final q = selectOnly(photoAssets)..addColumns([c]);
    return (await q.map((r) => r.read(c) ?? 0).getSingle());
  }

  /// The most-photographed labels above the confidence floor, biggest first.
  /// Callers filter these through `MemoryBuilder.isPresentableLabel` before
  /// paying for [assetsForLabel].
  Future<List<LabelTally>> topLabels({int limit = 40}) async {
    final count = photoLabels.assetId.count(distinct: true);
    final q = selectOnly(photoLabels)
      ..addColumns([photoLabels.label, count])
      ..where(
        photoLabels.confidence.isBiggerOrEqualValue(labelConfidenceFloor),
      )
      ..groupBy([photoLabels.label])
      ..orderBy([OrderingTerm.desc(count)])
      ..limit(limit);
    return [
      for (final r in await q.get())
        (label: r.read(photoLabels.label)!, assetCount: r.read(count)!),
    ];
  }

  /// Distinct dated assets carrying [label] above the confidence floor,
  /// newest first.
  Future<List<DatedAsset>> assetsForLabel(String label, {int limit = 200}) async {
    final q = select(photoLabels).join([
      innerJoin(
        photoAssets,
        photoAssets.assetId.equalsExp(photoLabels.assetId),
      ),
    ])
      ..where(
        photoLabels.label.equals(label) &
            photoLabels.confidence
                .isBiggerOrEqualValue(labelConfidenceFloor) &
            photoAssets.isDated.equals(true),
      )
      ..groupBy([photoAssets.assetId])
      ..orderBy([OrderingTerm.desc(photoAssets.createdAt)])
      ..limit(limit);
    return [
      for (final r in await q.get())
        (
          assetId: r.readTable(photoAssets).assetId,
          createdAt: r.readTable(photoAssets).createdAt,
        ),
    ];
  }

  // --- Apply ---------------------------------------------------------------

  /// Persists a generated [plan] in one transaction.
  ///
  /// Upserts on `sourceKey` so `seenAt`/`hidden` survive regeneration and the
  /// carousel doesn't reshuffle under the user; replaces each memory's entries;
  /// deletes memories the plan no longer contains.
  ///
  /// Asset ids are re-checked against `photo_asset` inside the transaction — a
  /// photo can be pruned between planning and applying, and a dangling FK would
  /// abort the whole batch.
  Future<void> applyPlan(List<PlannedMemory> plan) async {
    await transaction(() async {
      final keys = [for (final p in plan) p.sourceKey];
      if (keys.isEmpty) {
        await delete(memories).go();
        return;
      }
      await (delete(memories)..where((m) => m.sourceKey.isNotIn(keys))).go();

      final now = DateTime.now();
      for (final p in plan) {
        final live = await _liveAssetIds(p.assetIds);
        final ordered = [for (final id in p.assetIds) if (live.contains(id)) id];
        if (ordered.isEmpty) {
          // Every photo went away since planning — nothing to show.
          await (delete(memories)..where((m) => m.sourceKey.equals(p.sourceKey)))
              .go();
          continue;
        }
        final cover =
            live.contains(p.coverAssetId) ? p.coverAssetId : ordered.first;

        await into(memories).insert(
          MemoriesCompanion.insert(
            sourceKey: p.sourceKey,
            kind: p.kind.name,
            title: p.title,
            subtitle: Value(p.subtitle),
            coverAssetId: Value(cover),
            score: p.score,
            periodStart: Value(p.periodStart),
            periodEnd: Value(p.periodEnd),
            generatedAt: now,
          ),
          onConflict: DoUpdate(
            // Deliberately omits seenAt/hidden — user state is not regenerated.
            (_) => MemoriesCompanion(
              kind: Value(p.kind.name),
              title: Value(p.title),
              subtitle: Value(p.subtitle),
              coverAssetId: Value(cover),
              score: Value(p.score),
              periodStart: Value(p.periodStart),
              periodEnd: Value(p.periodEnd),
              generatedAt: Value(now),
            ),
            target: [memories.sourceKey],
          ),
        );

        final row = await (select(memories)
              ..where((m) => m.sourceKey.equals(p.sourceKey)))
            .getSingle();

        await (delete(memoryEntries)..where((e) => e.memoryId.equals(row.id)))
            .go();
        await batch((b) {
          for (var i = 0; i < ordered.length; i++) {
            b.insert(
              memoryEntries,
              MemoryEntriesCompanion.insert(
                memoryId: row.id,
                assetId: ordered[i],
                position: i,
              ),
            );
          }
        });
      }
    });
  }

  /// Which of [ids] still exist *and* belong in a memory.
  ///
  /// Videos are excluded: the player renders every page through `PhotoPage`, so
  /// a video would sit frozen on its poster frame for three seconds with no
  /// indication it is a clip. v1 memories are photo stories. Filtering here
  /// rather than in each projection covers all four memory kinds at once.
  Future<Set<String>> _liveAssetIds(List<String> ids) async {
    if (ids.isEmpty) return const {};
    final q = selectOnly(photoAssets)
      ..addColumns([photoAssets.assetId])
      ..where(
        photoAssets.assetId.isIn(ids) & photoAssets.isVideo.equals(false),
      );
    return {for (final r in await q.get()) r.read(photoAssets.assetId)!};
  }
}
