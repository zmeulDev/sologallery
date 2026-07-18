import 'dart:io' show File, Platform;
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:logging/logging.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:share_plus/share_plus.dart';

import '../features/library/domain/month_summary.dart';
import '../features/library/domain/year_month.dart';

/// Coarse photo-library access state, mapped from `photo_manager`'s
/// [PermissionState]. This is the only permission vocabulary the domain/UI
/// layers see — they never import `photo_manager` (see docs/spec.md#architecture).
enum PhotoAccess {
  /// The user has not been asked yet (iOS `.notDetermined`).
  notDetermined,

  /// Access refused or restricted — the grid cannot load.
  denied,

  /// Partial grant (iOS limited library, Android 14 "selected photos"):
  /// `photo_manager` returns only the user-picked subset.
  limited,

  /// Full library access.
  granted;

  /// Whether the gallery can query assets in this state.
  bool get canReadLibrary => this == granted || this == limited;
}

/// A pure, plugin-free projection of a `photo_manager` [AssetEntity]. The
/// domain and UI layers reference photos by [id] only (the asset-id-reference
/// rule); the full [AssetEntity] never leaves this service.
class AssetRef {
  const AssetRef({required this.id, required this.createdAt});

  final String id;
  final DateTime createdAt;
}

/// A pure, plugin-free projection of a single asset's metadata, shown in the
/// detail viewer's EXIF sheet. Only fields `photo_manager` exposes natively —
/// no camera make/model/ISO (that would need to parse the original file). Any
/// field may be null when the platform doesn't provide it.
class AssetDetail {
  const AssetDetail({
    required this.id,
    required this.width,
    required this.height,
    required this.createdAt,
    required this.orientationDegrees,
    required this.isVideo,
    this.videoDuration,
    this.sizeBytes,
    this.mimeType,
    this.latitude,
    this.longitude,
    this.title,
  });

  final String id;
  final int width;
  final int height;
  final DateTime createdAt;

  /// EXIF orientation as reported by the platform (degrees).
  final int orientationDegrees;
  final bool isVideo;

  /// Clip length for a video asset; null for images.
  final Duration? videoDuration;

  /// Original file size in bytes, best-effort (null if the file can't be read).
  final int? sizeBytes;
  final String? mimeType;
  final double? latitude;
  final double? longitude;
  final String? title;

  bool get hasGps => latitude != null && longitude != null;
}

/// The single wrapper around `photo_manager`. All permission handling, asset
/// and album queries, and thumbnail requests go through here — UI and other
/// layers never import `photo_manager` directly (see docs/spec.md#architecture).
///
/// Permission flow lands in Phase 2; asset/thumbnail queries are added on top of
/// this in the same phase.
class PhotoLibraryService {
  PhotoLibraryService();

  static final _log = Logger('SoloGallery.photos');

  /// Maps a raw plugin [PermissionState] onto our coarse [PhotoAccess].
  static PhotoAccess accessFromState(PermissionState state) {
    switch (state) {
      case PermissionState.authorized:
        return PhotoAccess.granted;
      case PermissionState.limited:
        return PhotoAccess.limited;
      case PermissionState.notDetermined:
        return PhotoAccess.notDetermined;
      case PermissionState.denied:
      case PermissionState.restricted:
        return PhotoAccess.denied;
    }
  }

  /// Current access without prompting the user.
  Future<PhotoAccess> currentAccess() async {
    final state = await PhotoManager.getPermissionState(
      requestOption: const PermissionRequestOption(),
    );
    _log.fine('Current photo access (no prompt): $state');
    return accessFromState(state);
  }

  /// Prompts for photo access (native dialog). Returns the resulting access.
  Future<PhotoAccess> requestAccess() async {
    final state = await PhotoManager.requestPermissionExtend();
    _log.info('Requested photo access -> $state');
    return accessFromState(state);
  }

  /// Opens the OS settings page for this app so the user can change a previously
  /// denied permission.
  Future<void> openSettings() {
    _log.fine('Opening system settings for photo permission');
    return PhotoManager.openSetting();
  }

  /// Re-presents the limited-access picker (iOS "Select More Photos" /
  /// Android 14 photo-picker subset) so the user can widen the granted subset.
  Future<void> presentLimited() {
    _log.fine('Presenting limited-access selection UI');
    return PhotoManager.presentLimited();
  }

  // --- Asset queries -------------------------------------------------------
  //
  // The gallery reads `photo_manager` directly (no cached `photo_asset` table
  // until the indexing phase). Month sections are built with *filtered* path
  // queries so only the six preview thumbnails per month are ever materialized
  // — full metadata for a whole library is never loaded, and originals are
  // never decoded for grid cells (CLAUDE.md Absolute rules).

  /// Resolves the single "all photos" path, optionally scoped to a
  /// `[min, max]` create-time window, ordered newest-first.
  Future<AssetPathEntity?> _imagesPath({DateTime? min, DateTime? max}) async {
    const assetFilter = FilterOption(
      sizeConstraint: SizeConstraint(ignoreSize: true),
      needTitle: false,
    );
    final filter = FilterOptionGroup(
      imageOption: assetFilter,
      videoOption: assetFilter,
      createTimeCond: (min != null && max != null)
          ? DateTimeCond(min: min, max: max)
          : DateTimeCond.def(),
      orders: const [
        OrderOption(type: OrderOptionType.createDate, asc: false),
      ],
    );
    final paths = await PhotoManager.getAssetPathList(
      onlyAll: true,
      type: RequestType.common,
      filterOption: filter,
    );
    return paths.isEmpty ? null : paths.first;
  }

  /// The descending list of calendar months spanned by the library. Includes
  /// months with no photos (callers skip empties via [monthSummary]); returns
  /// empty when the library has no images.
  Future<List<YearMonth>> monthsInLibrary() async {
    final path = await _imagesPath();
    if (path == null) return const [];
    final count = await path.assetCountAsync;
    if (count == 0) return const [];
    final newest = await path.getAssetListRange(start: 0, end: 1);
    final oldest = await path.getAssetListRange(start: count - 1, end: count);
    if (newest.isEmpty || oldest.isEmpty) return const [];
    _log.fine('Library spans ${newest.first.createDateTime} .. '
        '${oldest.first.createDateTime} ($count photos)');
    return YearMonth.descendingRange(
      YearMonth.fromDate(newest.first.createDateTime),
      YearMonth.fromDate(oldest.first.createDateTime),
    );
  }

  /// The exact photo count and up to six newest preview ids for [month], or
  /// null if the month has no photos.
  Future<MonthSummary?> monthSummary(YearMonth month) async {
    final path = await _imagesPath(
      min: month.start,
      max: month.end.subtract(const Duration(seconds: 1)),
    );
    if (path == null) return null;
    final count = await path.assetCountAsync;
    if (count == 0) return null;
    final preview = await path.getAssetListRange(
      start: 0,
      end: count < 6 ? count : 6,
    );
    return MonthSummary(
      month: month,
      count: count,
      previewAssetIds: [for (final a in preview) a.id],
    );
  }

  /// A page of asset references for one [month], newest first, for the
  /// full-month grid.
  Future<List<AssetRef>> monthAssets(
    YearMonth month, {
    required int page,
    required int pageSize,
  }) async {
    final path = await _imagesPath(
      min: month.start,
      max: month.end.subtract(const Duration(seconds: 1)),
    );
    if (path == null) return const [];
    final assets = await path.getAssetListPaged(page: page, size: pageSize);
    return [
      for (final a in assets) AssetRef(id: a.id, createdAt: a.createDateTime),
    ];
  }

  // --- Thumbnails ----------------------------------------------------------

  /// Cache of resolved [AssetEntity]s so repeated requests for the same id skip
  /// the `AssetEntity.fromId` round-trip. `photo_manager` caches the thumbnail
  /// bytes themselves natively.
  final Map<String, AssetEntity> _entityCache = {};

  /// Resolves (and caches) the [AssetEntity] for [assetId], or null if it can't
  /// be resolved (e.g. deleted).
  Future<AssetEntity?> _entity(String assetId) async {
    final cached = _entityCache[assetId];
    if (cached != null) return cached;
    final entity = await AssetEntity.fromId(assetId);
    if (entity != null) _entityCache[assetId] = entity;
    return entity;
  }

  /// A `width`×`height` thumbnail for [assetId], or null if the asset can't be
  /// resolved (e.g. deleted). Never decodes the original at full size
  /// (Absolute rules) — the detail viewer requests a screen-capped size, the
  /// grid a cell-sized one.
  Future<Uint8List?> thumbnail(String assetId, int width, int height) async {
    final entity = await _entity(assetId);
    if (entity == null) return null;
    return entity.thumbnailDataWithSize(ThumbnailSize(width, height));
  }

  /// A high-quality, screen-sized preview for the detail viewer — the whole
  /// image, uncropped, capped at [maxEdge] px on its longest side. Uses `fit`
  /// resize on iOS (the plain [thumbnailDataWithSize] hardcodes `fill`, which
  /// would crop); Android's scaler already fits within the box. The cap keeps a
  /// 48MP HEIC from decoding at full size (the OOM gotcha) while staying far
  /// sharper than a grid thumbnail. Never the full original (Absolute rules).
  Future<Uint8List?> previewImage(String assetId, int maxEdge) async {
    final entity = await _entity(assetId);
    if (entity == null) return null;
    final size = ThumbnailSize.square(maxEdge);
    final option = (Platform.isIOS || Platform.isMacOS)
        ? ThumbnailOption.ios(
            size: size,
            quality: 95,
            resizeContentMode: ResizeContentMode.fit,
          )
        : ThumbnailOption(size: size, quality: 95);
    return entity.thumbnailDataWithOption(option);
  }

  // --- Video ---------------------------------------------------------------

  /// The clip length for [assetId] if it is a video, else null (used to render
  /// the grid duration badge). Cheap — reads the cached entity's metadata; never
  /// opens the file.
  Future<Duration?> videoDuration(String assetId) async {
    final entity = await _entity(assetId);
    if (entity == null || entity.type != AssetType.video) return null;
    return entity.videoDuration;
  }

  /// Whether [assetId] is a video (drives the detail viewer's player-vs-image
  /// branch). Cheap — reads the cached entity's type.
  Future<bool> isVideoAsset(String assetId) async {
    final entity = await _entity(assetId);
    return entity?.type == AssetType.video;
  }

  /// The on-device file backing a video [assetId], for local playback, or null
  /// if it isn't a video or can't be resolved. A file reference only — the
  /// original is never copied or modified (Absolute rules), and playback is
  /// purely local (no network).
  Future<File?> videoFile(String assetId) async {
    final entity = await _entity(assetId);
    if (entity == null || entity.type != AssetType.video) return null;
    return entity.file;
  }

  // --- Detail metadata, delete, share -------------------------------------

  /// The `photo_manager`-native metadata for [assetId] shown in the EXIF sheet,
  /// or null if the asset can't be resolved. GPS is read via [latlngAsync]
  /// (the sync getters are always null on Android 10+); file size is read
  /// best-effort from the original file (a metadata read, never a decode).
  Future<AssetDetail?> assetDetail(String assetId) async {
    final entity = await _entity(assetId);
    if (entity == null) return null;

    final mimeType = await entity.mimeTypeAsync;
    final latLng = await entity.latlngAsync();
    var lat = latLng?.latitude;
    var lng = latLng?.longitude;
    // photo_manager reports 0,0 for "no location"; treat that as absent.
    if (lat == 0 && lng == 0) {
      lat = null;
      lng = null;
    }

    int? sizeBytes;
    try {
      final file = await entity.file;
      sizeBytes = await file?.length();
    } catch (e, st) {
      _log.fine('Could not read file size for $assetId', e, st);
    }

    return AssetDetail(
      id: entity.id,
      width: entity.width,
      height: entity.height,
      createdAt: entity.createDateTime,
      orientationDegrees: entity.orientation,
      isVideo: entity.type == AssetType.video,
      videoDuration:
          entity.type == AssetType.video ? entity.videoDuration : null,
      sizeBytes: sizeBytes,
      mimeType: mimeType,
      latitude: lat,
      longitude: lng,
      title: entity.title,
    );
  }

  /// Deletes [ids] from the device photo library via the OS (a native trash
  /// dialog is shown by the platform). Returns the ids actually deleted — empty
  /// if the user cancels. Evicts deleted entities from the cache.
  Future<List<String>> deleteAssets(List<String> ids) async {
    final deleted = await PhotoManager.editor.deleteWithIds(ids);
    for (final id in deleted) {
      _entityCache.remove(id);
    }
    _log.info('Deleted ${deleted.length}/${ids.length} asset(s) from library');
    return deleted;
  }

  /// Opens the OS share sheet for [ids], exporting each asset's original file.
  /// No library duplication — the shared file is the original the OS hands off.
  /// [sharePositionOrigin] anchors the sheet on iPad.
  Future<void> shareAssets(
    List<String> ids, {
    Rect? sharePositionOrigin,
  }) async {
    final files = <XFile>[];
    for (final id in ids) {
      final entity = await _entity(id);
      final file = await entity?.file;
      if (file != null) {
        files.add(XFile(file.path, mimeType: await entity?.mimeTypeAsync));
      }
    }
    if (files.isEmpty) {
      _log.warning('Nothing to share — no files resolved for $ids');
      return;
    }
    await SharePlus.instance.share(
      ShareParams(files: files, sharePositionOrigin: sharePositionOrigin),
    );
  }
}
