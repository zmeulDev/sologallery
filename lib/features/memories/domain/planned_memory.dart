import 'memory_kind.dart';

/// A minimal asset projection the memory builder reasons over — id + capture
/// date, nothing else. Deliberately thin: trip clustering scans up to 20k of
/// these, so full rows would be wasteful.
typedef DatedAsset = ({String assetId, DateTime createdAt});

/// A label and the assets carrying it, already confidence-filtered by the DAO.
typedef LabelCandidate = ({String label, List<DatedAsset> assets});

/// A named person cluster and the assets they appear in.
typedef PersonCandidate = ({
  int personId,
  String name,
  String? coverAssetId,
  List<DatedAsset> assets,
});

/// One memory the builder decided to create, before it touches the database.
///
/// [sourceKey] is the idempotence key: re-running generation with an unchanged
/// library must produce the same keys, so `MemoriesDao.applyPlan` can upsert
/// instead of wiping (preserving seen/hidden state). Everything here is pure
/// data — no Flutter, no Drift.
class PlannedMemory {
  const PlannedMemory({
    required this.sourceKey,
    required this.kind,
    required this.title,
    required this.assetIds,
    required this.score,
    this.subtitle,
    this.coverAssetId,
    this.periodStart,
    this.periodEnd,
  });

  final String sourceKey;
  final MemoryKind kind;
  final String title;
  final String? subtitle;

  /// Ordered oldest-first — a story reads forward in time.
  final List<String> assetIds;

  final String? coverAssetId;

  /// Carousel ordering weight; higher surfaces first.
  final double score;

  /// Display window; both null = always eligible.
  final DateTime? periodStart;
  final DateTime? periodEnd;

  @override
  String toString() => 'PlannedMemory($sourceKey, ${assetIds.length} assets)';
}
