import 'dart:io' show File;
import 'dart:typed_data';
import 'dart:ui' show Rect;

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
    this.previewBytes,
    Map<String, AssetDetail>? details,
    Map<String, Duration>? videoDurations,
    this.deleteResultOverride,
  })  : assets = List.of(assets ?? const []),
        details = details ?? const {},
        videoDurations = videoDurations ?? const {} {
    // Keep the newest-first ordering the real service guarantees.
    this.assets.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  PhotoAccess access;

  /// What [requestAccess] resolves to (defaults to [access]).
  final PhotoAccess? grantResult;

  final List<AssetRef> assets;
  final Uint8List? thumbnailBytes;
  final Uint8List? previewBytes;

  /// Per-id metadata returned by [assetDetail].
  final Map<String, AssetDetail> details;

  /// Ids that are videos, mapped to their clip length. An id present here is a
  /// video ([isVideoAsset]) and drives the grid badge ([videoDuration]).
  final Map<String, Duration> videoDurations;

  /// When set, [deleteAssets] returns this instead of the requested ids (used
  /// to simulate the user cancelling the OS trash dialog with an empty result).
  final List<String>? deleteResultOverride;

  int requestCount = 0;
  int openSettingsCount = 0;
  int presentLimitedCount = 0;
  final List<List<String>> deleteCalls = [];
  final List<List<String>> shareCalls = [];

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

  @override
  Future<Uint8List?> previewImage(String assetId, int maxEdge) async =>
      previewBytes ?? thumbnailBytes;

  @override
  Future<Duration?> videoDuration(String assetId) async =>
      videoDurations[assetId];

  @override
  Future<bool> isVideoAsset(String assetId) async =>
      videoDurations.containsKey(assetId);

  // Host tests never play real video; on-device patrol covers the real file.
  @override
  Future<File?> videoFile(String assetId) async => null;

  @override
  Future<AssetDetail?> assetDetail(String assetId) async => details[assetId];

  @override
  Future<List<String>> deleteAssets(List<String> ids) async {
    deleteCalls.add(ids);
    final deleted = deleteResultOverride ?? ids;
    assets.removeWhere((a) => deleted.contains(a.id));
    return deleted;
  }

  @override
  Future<void> shareAssets(List<String> ids, {Rect? sharePositionOrigin}) async {
    shareCalls.add(ids);
  }
}
