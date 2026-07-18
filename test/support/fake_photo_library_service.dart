import 'dart:io' show File;
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:sologallery/features/library/domain/month_summary.dart';
import 'package:sologallery/features/library/domain/older_summary.dart';
import 'package:sologallery/features/library/domain/year_month.dart';
import 'package:sologallery/features/search/domain/search_date.dart';
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
    List<AssetRef>? undatedAssets,
    this.thumbnailBytes,
    this.previewBytes,
    Map<String, AssetDetail>? details,
    Map<String, Duration>? videoDurations,
    this.deleteResultOverride,
  })  : assets = List.of(assets ?? const []),
        undatedAssets = List.of(undatedAssets ?? const []),
        details = details ?? const {},
        videoDurations = videoDurations ?? const {} {
    // Keep the newest-first ordering the real service guarantees.
    this.assets.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    this.undatedAssets.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  PhotoAccess access;

  /// What [requestAccess] resolves to (defaults to [access]).
  final PhotoAccess? grantResult;

  final List<AssetRef> assets;

  /// Assets with no capture date, surfaced via the "Older" section (mirrors the
  /// real service's `datetaken` null/0 bucket).
  final List<AssetRef> undatedAssets;
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
  Future<OlderSummary?> olderSummary() async {
    if (undatedAssets.isEmpty) return null;
    return OlderSummary(
      count: undatedAssets.length,
      previewAssetIds: [for (final a in undatedAssets.take(6)) a.id],
    );
  }

  @override
  Future<List<AssetRef>> olderAssets({
    required int page,
    required int pageSize,
  }) async {
    final start = page * pageSize;
    if (start >= undatedAssets.length) return const [];
    return undatedAssets.sublist(
      start,
      (start + pageSize).clamp(0, undatedAssets.length),
    );
  }

  bool _typeOk(MediaTypeFilter type, String id) {
    final isVideo = videoDurations.containsKey(id);
    switch (type) {
      case MediaTypeFilter.all:
        return true;
      case MediaTypeFilter.photos:
        return !isVideo;
      case MediaTypeFilter.videos:
        return isVideo;
    }
  }

  bool _windowOk(DateTime d, DateTime? min, DateTime? max) {
    if (min != null && d.isBefore(min)) return false;
    if (max != null && !d.isBefore(max)) return false;
    return true;
  }

  @override
  Future<List<AssetRef>> searchAssets({
    DateTime? min,
    DateTime? max,
    required MediaTypeFilter type,
    required int page,
    required int pageSize,
  }) async {
    // `assets` is already newest-first, mirroring the real path's ordering.
    final matched = [
      for (final a in assets)
        if (_typeOk(type, a.id) && _windowOk(a.createdAt, min, max)) a,
    ];
    final start = page * pageSize;
    if (start >= matched.length) return const [];
    return matched.sublist(start, (start + pageSize).clamp(0, matched.length));
  }

  @override
  Future<List<AssetRef>> resolveFavoriteMatches({
    required List<String> ids,
    DateTime? min,
    DateTime? max,
    required MediaTypeFilter type,
  }) async {
    final byId = {for (final a in [...assets, ...undatedAssets]) a.id: a};
    final matches = <AssetRef>[
      for (final id in ids)
        if (byId[id] case final a?)
          if (_typeOk(type, id) && _windowOk(a.createdAt, min, max)) a,
    ];
    matches.sort((x, y) => y.createdAt.compareTo(x.createdAt));
    return matches;
  }

  @override
  Future<List<String>> allAssetIds({
    required int page,
    required int pageSize,
  }) async {
    final all = [...assets, ...undatedAssets];
    final start = page * pageSize;
    if (start >= all.length) return const [];
    final end = start + pageSize > all.length ? all.length : start + pageSize;
    return [for (final a in all.sublist(start, end)) a.id];
  }

  @override
  Future<({DateTime createdAt, bool isVideo, int width, int height})?>
      assetIndexMeta(String assetId) async {
    final matches =
        [...assets, ...undatedAssets].where((a) => a.id == assetId);
    if (matches.isEmpty) return null;
    final match = matches.first;
    return (
      createdAt: match.createdAt,
      isVideo: videoDurations.containsKey(assetId),
      width: 100,
      height: 100,
    );
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
