import 'dart:io' show File;
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:sologallery/features/search/domain/search_date.dart';
import 'package:sologallery/services/photo_library_service.dart';

/// In-memory [PhotoLibraryService] for host tests. Backed by a fixed list of
/// [AssetRef]s (newest first); the metadata-sweep source ([libraryMetadataPage])
/// is derived from it, so provider/service logic is exercised against a
/// real-shaped data source without the plugin.
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
    List<DeviceFolder>? folders,
    Map<String, List<AssetRef>>? folderAssetsById,
  })  : assets = List.of(assets ?? const []),
        undatedAssets = List.of(undatedAssets ?? const []),
        details = details ?? const {},
        videoDurations = videoDurations ?? const {},
        folders = List.of(folders ?? const []),
        folderAssetsById = folderAssetsById ?? const {} {
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

  /// Device folders returned by [deviceFolders], in any order — the override
  /// applies the real service's sort and empty-folder filter.
  final List<DeviceFolder> folders;

  /// Per-folder assets (newest first) paged by [folderAssets]. A folder absent
  /// here pages empty, mirroring a folder that no longer resolves.
  final Map<String, List<AssetRef>> folderAssetsById;

  /// Makes [folderAssets] throw, so the folder screen's error branch can be
  /// exercised (an [AsyncNotifierProvider] has no `overrideWithValue`).
  bool failFolderAssets = false;

  int requestCount = 0;
  int openSettingsCount = 0;
  int presentLimitedCount = 0;
  int startChangeNotifyCount = 0;
  int stopChangeNotifyCount = 0;
  final List<List<String>> deleteCalls = [];
  final List<List<String>> shareCalls = [];

  /// The callback the indexer registered; invoke [fireLibraryChange] to
  /// simulate the device library changing (no plugin in host tests).
  void Function()? capturedOnChanged;

  void fireLibraryChange() => capturedOnChanged?.call();

  @override
  Future<void> startLibraryChangeNotify(void Function() onChanged) async {
    capturedOnChanged = onChanged;
    startChangeNotifyCount++;
  }

  @override
  Future<void> stopLibraryChangeNotify() async {
    capturedOnChanged = null;
    stopChangeNotifyCount++;
  }

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

  @override
  Future<List<({String id, DateTime createdAt, bool isVideo, int width, int height})>>
      libraryMetadataPage({
    required bool dated,
    required int page,
    required int pageSize,
  }) async {
    final source = dated ? assets : undatedAssets;
    final start = page * pageSize;
    if (start >= source.length) return const [];
    final end = start + pageSize > source.length ? source.length : start + pageSize;
    return [
      for (final a in source.sublist(start, end))
        (
          id: a.id,
          createdAt: a.createdAt,
          isVideo: videoDurations.containsKey(a.id),
          width: 100,
          height: 100,
        ),
    ];
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
  Future<List<DeviceFolder>> deviceFolders() async {
    final visible = [
      for (final f in folders)
        if (f.count > 0) f,
    ]..sort((a, b) {
        final byCount = b.count.compareTo(a.count);
        return byCount != 0 ? byCount : a.name.compareTo(b.name);
      });
    return visible;
  }

  @override
  Future<List<AssetRef>> folderAssets({
    required String folderId,
    required int page,
    required int pageSize,
  }) async {
    if (failFolderAssets) throw StateError('folder unavailable');
    final source = folderAssetsById[folderId] ?? const <AssetRef>[];
    final start = page * pageSize;
    if (start >= source.length) return const [];
    return source.sublist(start, (start + pageSize).clamp(0, source.length));
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
