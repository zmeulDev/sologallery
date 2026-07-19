import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/core/database/app_database.dart';
import 'package:sologallery/features/memories/domain/memory_kind.dart';
import 'package:sologallery/features/memories/domain/planned_memory.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  /// Memory entries FK into photo_asset, so every id must be cached first.
  Future<void> asset(
    String id, {
    DateTime? at,
    List<(String, double)> labels = const [],
  }) =>
      db.indexDao.upsertIndexed(
        assetId: id,
        createdAt: at ?? DateTime(2026, 7, 19, 12),
        isVideo: false,
        width: 100,
        height: 100,
        labels: labels,
        text: '',
      );

  PlannedMemory planned(
    String key,
    List<String> ids, {
    double score = 10,
    String title = 'Trip',
    String? cover,
    DateTime? periodStart,
    DateTime? periodEnd,
  }) =>
      PlannedMemory(
        sourceKey: key,
        kind: MemoryKind.trip,
        title: title,
        subtitle: 'sub',
        assetIds: ids,
        coverAssetId: cover ?? ids.first,
        score: score,
        periodStart: periodStart,
        periodEnd: periodEnd,
      );

  group('applyPlan', () {
    test('persists memories with ordered entries', () async {
      await asset('a');
      await asset('b');
      await asset('c');

      await db.memoriesDao.applyPlan([planned('trip:1', ['a', 'b', 'c'])]);

      final cards = await db.memoriesDao.watchActive().first;
      expect(cards, hasLength(1));
      expect(cards.single.title, 'Trip');
      expect(cards.single.assetCount, 3);

      final assets = await db.memoriesDao.assetsFor(cards.single.id);
      expect(assets.map((a) => a.id), ['a', 'b', 'c']);
    });

    test('is idempotent — re-applying preserves seen and hidden state',
        () async {
      await asset('a');
      await asset('b');
      await db.memoriesDao.applyPlan([planned('trip:1', ['a', 'b'])]);

      final id = (await db.memoriesDao.watchActive().first).single.id;
      await db.memoriesDao.markSeen(id);

      // Same key, refreshed content.
      await db.memoriesDao.applyPlan([
        planned('trip:1', ['a', 'b'], title: 'Renamed'),
      ]);

      final row = await db.memoriesDao.memoryById(id);
      expect(row, isNotNull, reason: 'upsert must reuse the row, not replace it');
      expect(row!.title, 'Renamed');
      expect(row.seenAt, isNotNull, reason: 'user state must survive');
    });

    test('a hidden memory stays hidden across regeneration', () async {
      await asset('a');
      await db.memoriesDao.applyPlan([planned('trip:1', ['a'])]);
      final id = (await db.memoriesDao.watchActive().first).single.id;

      await db.memoriesDao.hide(id);
      await db.memoriesDao.applyPlan([planned('trip:1', ['a'])]);

      expect(await db.memoriesDao.watchActive().first, isEmpty);
      expect((await db.memoriesDao.memoryById(id))!.hidden, isTrue);
    });

    test('deletes memories the plan no longer contains', () async {
      await asset('a');
      await db.memoriesDao.applyPlan([
        planned('trip:1', ['a']),
        planned('trip:2', ['a']),
      ]);
      expect(await db.memoriesDao.watchActive().first, hasLength(2));

      await db.memoriesDao.applyPlan([planned('trip:2', ['a'])]);

      final left = await db.memoriesDao.watchActive().first;
      expect(left, hasLength(1));
      expect((await db.memoriesDao.memoryById(left.single.id))!.sourceKey,
          'trip:2');
    });

    test('an empty plan clears everything', () async {
      await asset('a');
      await db.memoriesDao.applyPlan([planned('trip:1', ['a'])]);

      await db.memoriesDao.applyPlan(const []);
      expect(await db.memoriesDao.watchActive().first, isEmpty);
    });

    test('skips asset ids pruned between planning and applying', () async {
      await asset('a');
      // 'ghost' was planned but has since been deleted from the cache — a raw
      // insert would abort the transaction on the FK.
      await db.memoriesDao.applyPlan([planned('trip:1', ['a', 'ghost'])]);

      final card = (await db.memoriesDao.watchActive().first).single;
      expect(card.assetCount, 1);
      expect((await db.memoriesDao.assetsFor(card.id)).map((a) => a.id), ['a']);
    });

    test('leaves videos out of the story', () async {
      await asset('photo');
      await db.indexDao.upsertIndexed(
        assetId: 'clip',
        createdAt: DateTime(2026, 7, 19, 12),
        isVideo: true,
        width: 100,
        height: 100,
        labels: const [],
        text: '',
      );

      await db.memoriesDao.applyPlan([planned('trip:1', ['photo', 'clip'])]);

      final card = (await db.memoriesDao.watchActive().first).single;
      expect(card.assetCount, 1);
      expect((await db.memoriesDao.assetsFor(card.id)).map((a) => a.id),
          ['photo']);
    });

    test('drops a memory whose every asset is gone', () async {
      await db.memoriesDao.applyPlan([planned('trip:1', ['ghost'])]);
      expect(await db.memoriesDao.watchActive().first, isEmpty);
    });

    test('falls back to a live cover when the planned cover is gone', () async {
      await asset('a');
      await db.memoriesDao
          .applyPlan([planned('trip:1', ['a'], cover: 'ghost')]);

      expect((await db.memoriesDao.watchActive().first).single.coverAssetId, 'a');
    });
  });

  group('cascades', () {
    test('deleting a photo removes its entry but keeps the memory', () async {
      await asset('a');
      await asset('b');
      await db.memoriesDao.applyPlan([planned('trip:1', ['a', 'b'])]);

      await db.indexDao.deleteAssets(['b']);

      final card = (await db.memoriesDao.watchActive().first).single;
      expect(card.assetCount, 1);
      expect((await db.memoriesDao.assetsFor(card.id)).map((a) => a.id), ['a']);
    });

    test('deleting the cover photo nulls the cover, not the memory', () async {
      await asset('a');
      await asset('b');
      await db.memoriesDao
          .applyPlan([planned('trip:1', ['a', 'b'], cover: 'a')]);

      await db.indexDao.deleteAssets(['a']);

      final cards = await db.memoriesDao.watchActive().first;
      expect(cards, hasLength(1), reason: 'cover is setNull, never cascade');
      expect(cards.single.coverAssetId, isNull);
    });

    test('a memory with no surviving photos leaves the carousel', () async {
      await asset('a');
      await db.memoriesDao.applyPlan([planned('trip:1', ['a'])]);

      await db.indexDao.deleteAssets(['a']);

      // watchActive inner-joins entries, so an empty memory cannot surface.
      expect(await db.memoriesDao.watchActive().first, isEmpty);
    });
  });

  group('watchActive', () {
    test('orders by score and honours the limit', () async {
      await asset('a');
      await db.memoriesDao.applyPlan([
        planned('trip:1', ['a'], score: 1, title: 'low'),
        planned('trip:2', ['a'], score: 9, title: 'high'),
        planned('trip:3', ['a'], score: 5, title: 'mid'),
      ]);

      final cards = await db.memoriesDao.watchActive(limit: 2).first;
      expect(cards.map((c) => c.title), ['high', 'mid']);
    });

    test('excludes a memory whose display window has closed', () async {
      await asset('a');
      final now = DateTime(2026, 7, 19, 12);
      await db.memoriesDao.applyPlan([
        planned('otd:yesterday', ['a'],
            periodStart: DateTime(2026, 7, 18),
            periodEnd: DateTime(2026, 7, 19)),
        planned('otd:today', ['a'],
            periodStart: DateTime(2026, 7, 19),
            periodEnd: DateTime(2026, 7, 20),
            title: 'today'),
      ]);

      final cards = await db.memoriesDao.watchActive(now: now).first;
      expect(cards.map((c) => c.title), ['today']);
    });
  });

  group('generation inputs', () {
    test('onThisDay matches the local calendar day, all years', () async {
      // Local-midnight-adjacent times: bucketing these by UTC (Drift's
      // `.month`/`.day`) would put them on the wrong day in any non-UTC zone.
      await asset('early', at: DateTime(2024, 7, 19, 0, 30));
      await asset('late', at: DateTime(2023, 7, 19, 23, 30));
      await asset('dayBefore', at: DateTime(2024, 7, 18, 23, 30));
      await asset('dayAfter', at: DateTime(2024, 7, 20, 0, 30));

      final hits = await db.memoriesDao.onThisDay(7, 19);
      expect(hits.map((a) => a.assetId), unorderedEquals(['early', 'late']));
    });

    test('recentDatedProjection returns newest first, bounded', () async {
      for (var i = 0; i < 5; i++) {
        await asset('a$i', at: DateTime(2025, 1, 1 + i));
      }

      final rows = await db.memoriesDao.recentDatedProjection(limit: 3);
      expect(rows.map((r) => r.assetId), ['a4', 'a3', 'a2']);
    });

    test('topLabels counts distinct assets above the confidence floor',
        () async {
      await asset('a', labels: [('Dog', 0.9), ('Cat', 0.5)]);
      await asset('b', labels: [('Dog', 0.8)]);
      await asset('c', labels: [('Cat', 0.95)]);

      final tallies = await db.memoriesDao.topLabels();
      expect(tallies.first, (label: 'Dog', assetCount: 2));
      // Cat's 0.5 detection is below the floor, so only 'c' counts.
      expect(
        tallies.firstWhere((t) => t.label == 'Cat').assetCount,
        1,
      );
    });

    test('assetsForLabel returns each asset once, newest first', () async {
      await asset('a', at: DateTime(2025, 1, 1), labels: [('Dog', 0.9)]);
      await asset('b', at: DateTime(2025, 6, 1), labels: [('Dog', 0.9)]);
      await asset('c', at: DateTime(2025, 3, 1), labels: [('Cat', 0.9)]);

      final rows = await db.memoriesDao.assetsForLabel('Dog');
      expect(rows.map((r) => r.assetId), ['b', 'a']);
    });
  });

  test('clearMemories wipes everything', () async {
    await asset('a');
    await db.memoriesDao.applyPlan([planned('trip:1', ['a'])]);

    await db.memoriesDao.clearMemories();

    expect(await db.memoriesDao.watchActive().first, isEmpty);
    expect(await db.select(db.memoryEntries).get(), isEmpty,
        reason: 'entries cascade from the memory');
  });
}
