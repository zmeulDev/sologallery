import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/features/memories/domain/memory_builder.dart';
import 'package:sologallery/features/memories/domain/memory_kind.dart';
import 'package:sologallery/features/memories/domain/planned_memory.dart';

/// The builder is pure and clock-injected, so every threshold is testable at
/// its exact boundary — that is the point of keeping it out of the DAO.
void main() {
  final today = DateTime(2026, 7, 19);

  List<DatedAsset> assets(int n, DateTime start, {Duration step = const Duration(minutes: 5), String prefix = 'a'}) => [
        for (var i = 0; i < n; i++)
          (assetId: '$prefix$i', createdAt: start.add(step * i)),
      ];

  List<PlannedMemory> build({
    List<DatedAsset> onThisDay = const [],
    List<DatedAsset> recentDated = const [],
    List<LabelCandidate> labels = const [],
    List<PersonCandidate> people = const [],
  }) =>
      MemoryBuilder.build(
        today: today,
        onThisDay: onThisDay,
        recentDated: recentDated,
        labels: labels,
        people: people,
      );

  group('on this day', () {
    test('needs the minimum number of assets', () {
      final four = assets(4, DateTime(2024, 7, 19, 10));
      expect(build(onThisDay: four), isEmpty);

      final five = assets(5, DateTime(2024, 7, 19, 10));
      expect(build(onThisDay: five), hasLength(1));
    });

    test('makes one memory per past year and ignores the current year', () {
      final plan = build(
        onThisDay: [
          ...assets(6, DateTime(2024, 7, 19, 10), prefix: 'x'),
          ...assets(6, DateTime(2023, 7, 19, 10), prefix: 'y'),
          // Same day this year — not a memory yet.
          ...assets(6, DateTime(2026, 7, 19, 10), prefix: 'z'),
        ],
      );

      expect(plan.map((m) => m.sourceKey),
          containsAll(['otd:07-19:2024', 'otd:07-19:2023']));
      expect(plan.any((m) => m.sourceKey.endsWith('2026')), isFalse);
      expect(plan.every((m) => m.kind == MemoryKind.onThisDay), isTrue);
    });

    test('is scoped to the day itself via its display window', () {
      final plan = build(onThisDay: assets(6, DateTime(2024, 7, 19, 10)));

      expect(plan.single.periodStart, DateTime(2026, 7, 19));
      expect(plan.single.periodEnd, DateTime(2026, 7, 20));
    });
  });

  group('trips', () {
    test('splits on a gap longer than tripGap', () {
      // Two bursts 5 days apart — two trips, not one.
      final plan = build(
        recentDated: [
          ...assets(25, DateTime(2025, 6, 1, 9), step: const Duration(minutes: 10), prefix: 'a'),
          ...assets(25, DateTime(2025, 6, 10, 9), step: const Duration(minutes: 10), prefix: 'b'),
        ],
      );

      expect(plan.where((m) => m.kind == MemoryKind.trip), hasLength(2));
      expect(plan.map((m) => m.sourceKey),
          containsAll(['trip:2025-06-01', 'trip:2025-06-10']));
    });

    test('a gap exactly at the threshold stays one trip', () {
      // 20 assets, then exactly 3 days later 20 more: gap == tripGap, not >.
      final first = assets(20, DateTime(2025, 6, 1, 9), step: const Duration(minutes: 1));
      final second = assets(20, DateTime(2025, 6, 4, 9, 19), step: const Duration(minutes: 1), prefix: 'b');

      final plan = build(recentDated: [...first, ...second]);
      expect(plan.where((m) => m.kind == MemoryKind.trip), hasLength(1));
    });

    test('needs the minimum burst size', () {
      expect(
        build(recentDated: assets(19, DateTime(2025, 6, 1, 9))),
        isEmpty,
      );
      expect(
        build(recentDated: assets(20, DateTime(2025, 6, 1, 9))),
        hasLength(1),
      );
    });

    test('drops clusters spanning longer than maxTripSpan', () {
      // 30 assets dribbled out over 12 days with no 3-day gap: ordinary life.
      final plan = build(
        recentDated: assets(30, DateTime(2025, 6, 1),
            step: const Duration(hours: 10)),
      );
      expect(plan, isEmpty);
    });

    test('titles by part of month and year', () {
      final early = build(recentDated: assets(20, DateTime(2025, 6, 3, 9)));
      expect(early.single.title, 'Early June');
      expect(early.single.subtitle, '2025');

      final late = build(recentDated: assets(20, DateTime(2025, 6, 25, 9)));
      expect(late.single.title, 'Late June');
    });

    test('accepts a newest-first projection', () {
      final ordered = assets(20, DateTime(2025, 6, 1, 9));
      final reversed = ordered.reversed.toList();

      final a = build(recentDated: ordered).single;
      final b = build(recentDated: reversed).single;
      expect(a.sourceKey, b.sourceKey);
      expect(a.assetIds, b.assetIds);
    });
  });

  group('themes', () {
    LabelCandidate labelled(String label, int n) =>
        (label: label, assets: assets(n, DateTime(2025, 5, 1), prefix: label));

    test('only allowlisted labels become memories', () {
      final plan = build(
        labels: [
          labelled('Dog', 20),
          // Real ML Kit labels, but unpresentable as a memory title.
          labelled('Person', 400),
          labelled('Room', 300),
        ],
      );

      expect(plan, hasLength(1));
      expect(plan.single.title, 'Dog');
      expect(plan.single.sourceKey, 'theme:dog');
    });

    test('needs the minimum asset count', () {
      expect(build(labels: [labelled('Dog', 11)]), isEmpty);
      expect(build(labels: [labelled('Dog', 12)]), hasLength(1));
    });

    test('caps the number of themes', () {
      final plan = build(
        labels: [
          for (final l in ['Dog', 'Cat', 'Food', 'Beach', 'Snow'])
            labelled(l, 20),
        ],
      );
      expect(plan, hasLength(MemoryBuilder.maxThemes));
    });
  });

  group('people', () {
    test('needs photos spread across multiple months', () {
      final oneMonth = (
        personId: 1,
        name: 'Anna',
        coverAssetId: null,
        assets: assets(20, DateTime(2025, 5, 1), step: const Duration(hours: 1)),
      );
      expect(build(people: [oneMonth]), isEmpty);

      final spread = (
        personId: 1,
        name: 'Anna',
        coverAssetId: null,
        assets: [
          ...assets(10, DateTime(2025, 5, 1), prefix: 'm'),
          ...assets(10, DateTime(2025, 9, 1), prefix: 'n'),
        ],
      );
      final plan = build(people: [spread]);
      expect(plan.single.title, 'Anna');
      expect(plan.single.sourceKey, 'person:1');
    });

    test('keeps the person avatar as the cover', () {
      final plan = build(
        people: [
          (
            personId: 7,
            name: 'Anna',
            coverAssetId: 'avatar',
            assets: [
              ...assets(10, DateTime(2025, 5, 1), prefix: 'm'),
              ...assets(10, DateTime(2025, 9, 1), prefix: 'n'),
            ],
          ),
        ],
      );
      expect(plan.single.coverAssetId, 'avatar');
    });
  });

  group('shared rules', () {
    test('assets are ordered oldest-first', () {
      final plan = build(onThisDay: assets(6, DateTime(2024, 7, 19, 10)));
      expect(plan.single.assetIds, ['a0', 'a1', 'a2', 'a3', 'a4', 'a5']);
    });

    test('caps assets per memory by sampling across the whole span', () {
      final plan = build(
        recentDated: assets(200, DateTime(2025, 6, 1),
            step: const Duration(minutes: 30)),
      );

      final ids = plan.single.assetIds;
      expect(ids, hasLength(MemoryBuilder.maxAssetsPerMemory));
      // Sampled, not truncated: the story still reaches the end of the trip.
      expect(ids.first, 'a0');
      expect(ids.last, 'a195');
    });

    test('On This Day outranks a same-era trip', () {
      final plan = build(
        onThisDay: assets(6, DateTime(2025, 7, 19, 10), prefix: 'o'),
        recentDated: assets(25, DateTime(2025, 7, 1, 9), prefix: 't'),
      );
      expect(plan.first.kind, MemoryKind.onThisDay);
    });

    test('caps the total number of memories', () {
      final plan = build(
        onThisDay: [
          for (var y = 2010; y < 2026; y++)
            ...assets(6, DateTime(y, 7, 19, 10), prefix: 'y$y'),
        ],
      );
      expect(plan, hasLength(MemoryBuilder.maxMemories));
    });

    test('is deterministic — same input, same plan', () {
      final input = assets(25, DateTime(2025, 6, 1, 9));
      final a = build(recentDated: input);
      final b = build(recentDated: input);

      expect(a.map((m) => m.sourceKey), b.map((m) => m.sourceKey));
      expect(a.map((m) => m.assetIds), b.map((m) => m.assetIds));
      expect(a.map((m) => m.score), b.map((m) => m.score));
    });
  });
}
