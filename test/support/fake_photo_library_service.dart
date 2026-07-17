import 'dart:typed_data';

import 'package:sologallery/features/library/domain/month_summary.dart';
import 'package:sologallery/features/library/domain/year_month.dart';
import 'package:sologallery/services/photo_library_service.dart';

/// In-memory [PhotoLibraryService] for host tests. Backed by a fixed list of
/// [AssetRef]s (newest first); month queries are derived from it exactly as the
/// real service derives them from `photo_manager`, so provider/UI logic is
/// exercised against a real-shaped data source without the plugin.
///
/// This fake is paired with an on-device patrol test exercising the real
/// `photo_manager` path (CLAUDE.md "fake-pairing rule").
class FakePhotoLibraryService extends PhotoLibraryService {
  FakePhotoLibraryService({
    this.access = PhotoAccess.granted,
    this.grantResult,
    List<AssetRef>? assets,
    this.thumbnailBytes,
  }) : assets = List.of(assets ?? const []) {
    // Keep the newest-first ordering the real service guarantees.
    this.assets.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  PhotoAccess access;

  /// What [requestAccess] resolves to (defaults to [access]).
  final PhotoAccess? grantResult;

  final List<AssetRef> assets;
  final Uint8List? thumbnailBytes;

  int requestCount = 0;
  int openSettingsCount = 0;
  int presentLimitedCount = 0;

  @override
  Future<PhotoAccess> currentAccess() async => access;

  @override
  Future<PhotoAccess> requestAccess() async {
    requestCount++;
    return access = grantResult ?? access;
  }

  @override
  Future<void> openSettings() async => openSettingsCount++;

  @override
  Future<void> presentLimited() async => presentLimitedCount++;

  List<AssetRef> _inMonth(YearMonth m) =>
      assets.where((a) => YearMonth.fromDate(a.createdAt) == m).toList();

  @override
  Future<List<YearMonth>> monthsInLibrary() async {
    if (assets.isEmpty) return const [];
    return YearMonth.descendingRange(
      YearMonth.fromDate(assets.first.createdAt),
      YearMonth.fromDate(assets.last.createdAt),
    );
  }

  @override
  Future<MonthSummary?> monthSummary(YearMonth month) async {
    final inMonth = _inMonth(month);
    if (inMonth.isEmpty) return null;
    return MonthSummary(
      month: month,
      count: inMonth.length,
      previewAssetIds: [for (final a in inMonth.take(6)) a.id],
    );
  }

  @override
  Future<List<AssetRef>> monthAssets(
    YearMonth month, {
    required int page,
    required int pageSize,
  }) async {
    final inMonth = _inMonth(month);
    final start = page * pageSize;
    if (start >= inMonth.length) return const [];
    return inMonth.sublist(start, (start + pageSize).clamp(0, inMonth.length));
  }

  @override
  Future<Uint8List?> thumbnail(String assetId, int width, int height) async =>
      thumbnailBytes;
}
