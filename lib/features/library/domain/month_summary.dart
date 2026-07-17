import 'year_month.dart';

/// One month section on the Library screen: its [month], the total number of
/// photos in it ([count]), and up to six [previewAssetIds] (newest first) shown
/// in the section preview grid. Photos are referenced by asset id only — the
/// asset-id-reference rule (see docs/spec.md#architecture).
class MonthSummary {
  const MonthSummary({
    required this.month,
    required this.count,
    required this.previewAssetIds,
  });

  final YearMonth month;
  final int count;
  final List<String> previewAssetIds;

  /// Whether there are more photos than the preview shows.
  bool get hasMoreThanPreview => count > previewAssetIds.length;
}
