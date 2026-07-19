import 'memory_kind.dart';
import 'planned_memory.dart';

/// Decides which memories exist, from thin metadata projections.
///
/// Pure Dart — no Flutter, no Drift, no clock. The caller injects `today`, so
/// every rule is testable at its boundary. Given identical inputs this always
/// returns identical output (same order, same `sourceKey`s); `applyPlan`
/// depends on that to be idempotent.
///
/// The DAO does the *fetching* (bounded, confidence-filtered); this does the
/// *deciding*. See docs/plans/memories-section.md.
abstract final class MemoryBuilder {
  // --- Tunables ------------------------------------------------------------
  // All thresholds live here so tuning after real-device output is one edit.

  /// An "On this day" memory needs at least this many photos from that year.
  static const minOnThisDayAssets = 5;

  /// A gap longer than this ends a trip cluster.
  static const tripGap = Duration(days: 3);

  /// A cluster spanning longer than this is ordinary life, not a trip.
  static const maxTripSpan = Duration(days: 10);

  static const minTripAssets = 20;
  static const minThemeAssets = 12;

  /// A person memory needs their photos spread over at least this many
  /// distinct months — otherwise it is really just one event.
  static const minPersonMonths = 2;

  /// Photos per memory. A story longer than this outstays its welcome, and it
  /// bounds decode memory in the player.
  static const maxAssetsPerMemory = 40;

  static const maxTrips = 4;
  static const maxThemes = 3;
  static const maxPeople = 2;

  /// Total memories surfaced in the carousel.
  static const maxMemories = 10;

  /// ML Kit's base label set is coarse and mostly unpresentable as a memory
  /// title ("Person", "Room", "Event"). Only these become themes — anything
  /// outside the allowlist is dropped, which is the entire quality defense for
  /// theme memories. Expect to tune this against real on-device output.
  static const presentableLabels = <String>{
    'Beach',
    'Bicycle',
    'Bird',
    'Boat',
    'Bridge',
    'Building',
    'Cat',
    'Christmas',
    'Concert',
    'Dance',
    'Dessert',
    'Dog',
    'Flower',
    'Food',
    'Fireworks',
    'Forest',
    'Garden',
    'Horse',
    'Lake',
    'Mountain',
    'Motorcycle',
    'Museum',
    'Nature',
    'Party',
    'Pet',
    'Plant',
    'Sky',
    'Snow',
    'Sport',
    'Sunset',
    'Swimming',
    'Waterfall',
    'Wedding',
  };

  /// Whether [label] may become a theme memory. Callers use this to avoid
  /// fetching assets for labels that could never qualify.
  static bool isPresentableLabel(String label) =>
      presentableLabels.contains(label);

  // --- Entry point ---------------------------------------------------------

  /// Plans every memory, ranked and capped.
  ///
  /// [onThisDay] must already be filtered to assets sharing [today]'s local
  /// month+day in *previous* years. [recentDated] is a newest-first projection
  /// used for trip clustering. [labels] and [people] are pre-hydrated
  /// candidates.
  static List<PlannedMemory> build({
    required DateTime today,
    required List<DatedAsset> onThisDay,
    required List<DatedAsset> recentDated,
    required List<LabelCandidate> labels,
    required List<PersonCandidate> people,
  }) {
    final planned = <PlannedMemory>[
      ..._onThisDay(today, onThisDay),
      ..._trips(today, recentDated),
      ..._themes(today, labels),
      ..._people(today, people),
    ]..sort((a, b) {
        final byScore = b.score.compareTo(a.score);
        // Tie-break on the key so ordering is total and deterministic.
        return byScore != 0 ? byScore : a.sourceKey.compareTo(b.sourceKey);
      });

    return planned.take(maxMemories).toList(growable: false);
  }

  // --- Types ---------------------------------------------------------------

  static List<PlannedMemory> _onThisDay(DateTime today, List<DatedAsset> all) {
    final byYear = <int, List<DatedAsset>>{};
    for (final a in all) {
      if (a.createdAt.year >= today.year) continue;
      byYear.putIfAbsent(a.createdAt.year, () => []).add(a);
    }

    // Only surfaced on the day itself.
    final start = DateTime(today.year, today.month, today.day);
    final end = start.add(const Duration(days: 1));

    final out = <PlannedMemory>[];
    for (final year in byYear.keys.toList()..sort()) {
      final assets = byYear[year]!;
      if (assets.length < minOnThisDayAssets) continue;
      final ordered = _prepare(assets);
      out.add(
        PlannedMemory(
          sourceKey: 'otd:${_mmdd(today)}:$year',
          kind: MemoryKind.onThisDay,
          title: 'On this day',
          subtitle: '$year',
          assetIds: [for (final a in ordered) a.assetId],
          coverAssetId: _cover(ordered),
          score: _score(MemoryKind.onThisDay, today, ordered),
          periodStart: start,
          periodEnd: end,
        ),
      );
    }
    return out;
  }

  static List<PlannedMemory> _trips(DateTime today, List<DatedAsset> recent) {
    // The projection arrives newest-first; cluster oldest-first so positions
    // and boundaries read forward in time.
    final sorted = [...recent]..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final clusters = <List<DatedAsset>>[];
    var current = <DatedAsset>[];
    for (final a in sorted) {
      if (current.isEmpty) {
        current = [a];
        continue;
      }
      final gap = a.createdAt.difference(current.last.createdAt);
      if (gap > tripGap) {
        clusters.add(current);
        current = [a];
      } else {
        current.add(a);
      }
    }
    if (current.isNotEmpty) clusters.add(current);

    final candidates = <PlannedMemory>[];
    for (final c in clusters) {
      if (c.length < minTripAssets) continue;
      final span = c.last.createdAt.difference(c.first.createdAt);
      if (span > maxTripSpan) continue;

      final ordered = _prepare(c);
      final startedOn = c.first.createdAt;
      candidates.add(
        PlannedMemory(
          sourceKey: 'trip:${_isoDate(startedOn)}',
          kind: MemoryKind.trip,
          title: '${_partOfMonth(startedOn.day)} ${_monthName(startedOn.month)}',
          subtitle: '${startedOn.year}',
          assetIds: [for (final a in ordered) a.assetId],
          coverAssetId: _cover(ordered),
          score: _score(MemoryKind.trip, today, ordered),
        ),
      );
    }

    return _topBy(candidates, maxTrips);
  }

  static List<PlannedMemory> _themes(
    DateTime today,
    List<LabelCandidate> labels,
  ) {
    final candidates = <PlannedMemory>[];
    for (final l in labels) {
      if (!isPresentableLabel(l.label)) continue;
      if (l.assets.length < minThemeAssets) continue;

      final ordered = _prepare(l.assets);
      candidates.add(
        PlannedMemory(
          sourceKey: 'theme:${l.label.toLowerCase()}',
          kind: MemoryKind.theme,
          title: l.label,
          subtitle: '${l.assets.length} photos',
          assetIds: [for (final a in ordered) a.assetId],
          coverAssetId: _cover(ordered),
          score: _score(MemoryKind.theme, today, ordered),
        ),
      );
    }
    return _topBy(candidates, maxThemes);
  }

  static List<PlannedMemory> _people(
    DateTime today,
    List<PersonCandidate> people,
  ) {
    final candidates = <PlannedMemory>[];
    for (final p in people) {
      if (p.assets.length < minOnThisDayAssets) continue;
      final months = <String>{
        for (final a in p.assets) '${a.createdAt.year}-${a.createdAt.month}',
      };
      if (months.length < minPersonMonths) continue;

      final ordered = _prepare(p.assets);
      candidates.add(
        PlannedMemory(
          sourceKey: 'person:${p.personId}',
          kind: MemoryKind.person,
          title: p.name,
          subtitle: 'Over the years',
          assetIds: [for (final a in ordered) a.assetId],
          // Keep the person's established avatar photo as the card cover so
          // People and Memories agree on who this is.
          coverAssetId: p.coverAssetId ?? _cover(ordered),
          score: _score(MemoryKind.person, today, ordered),
        ),
      );
    }
    return _topBy(candidates, maxPeople);
  }

  // --- Shared helpers ------------------------------------------------------

  /// Sorts oldest-first and caps to [maxAssetsPerMemory] by evenly sampling
  /// across the span — a 200-photo trip should still open on day one and close
  /// on the last day, not stop 40 photos in.
  static List<DatedAsset> _prepare(List<DatedAsset> assets) {
    final sorted = [...assets]
      ..sort((a, b) {
        final byDate = a.createdAt.compareTo(b.createdAt);
        // Stable regardless of input order — ids break date ties.
        return byDate != 0 ? byDate : a.assetId.compareTo(b.assetId);
      });
    if (sorted.length <= maxAssetsPerMemory) return sorted;

    final step = sorted.length / maxAssetsPerMemory;
    return [
      for (var i = 0; i < maxAssetsPerMemory; i++) sorted[(i * step).floor()],
    ];
  }

  /// The middle photo — more representative of a story than its first frame.
  static String? _cover(List<DatedAsset> ordered) =>
      ordered.isEmpty ? null : ordered[ordered.length ~/ 2].assetId;

  /// Kind weight decayed by how long ago the memory's newest photo was taken,
  /// so an old theme never outranks a fresh trip.
  static double _score(MemoryKind kind, DateTime today, List<DatedAsset> ordered) {
    const weights = {
      MemoryKind.onThisDay: 100.0,
      MemoryKind.trip: 70.0,
      MemoryKind.person: 50.0,
      MemoryKind.theme: 30.0,
    };
    final newest = ordered.last.createdAt;
    final years = today.difference(newest).inDays / 365.0;
    return weights[kind]! / (1.0 + (years < 0 ? 0 : years));
  }

  static List<PlannedMemory> _topBy(List<PlannedMemory> items, int cap) {
    items.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      return byScore != 0 ? byScore : a.sourceKey.compareTo(b.sourceKey);
    });
    return items.take(cap).toList();
  }

  static String _mmdd(DateTime d) =>
      '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String _isoDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static String _partOfMonth(int day) => switch (day) {
        <= 10 => 'Early',
        <= 20 => 'Mid',
        _ => 'Late',
      };

  static const _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static String _monthName(int month) => _monthNames[month - 1];
}
