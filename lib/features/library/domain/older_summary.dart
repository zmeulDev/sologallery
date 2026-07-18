/// The trailing "Older" section on the Library screen: photos with no capture
/// date (`DATE_TAKEN` null/0), which can't be placed in a calendar month. Holds
/// the total [count] and up to six [previewAssetIds] (newest-added first) shown
/// in the section preview grid. Photos are referenced by asset id only — the
/// asset-id-reference rule (see docs/spec.md#architecture).
class OlderSummary {
  const OlderSummary({
    required this.count,
    required this.previewAssetIds,
  });

  final int count;
  final List<String> previewAssetIds;

  /// Whether there are more photos than the preview shows.
  bool get hasMoreThanPreview => count > previewAssetIds.length;
}
