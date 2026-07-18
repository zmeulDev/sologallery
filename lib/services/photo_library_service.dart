import 'dart:io' show File, Platform;
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:logging/logging.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:share_plus/share_plus.dart';

import '../features/library/domain/month_summary.dart';
import '../features/library/domain/older_summary.dart';
import '../features/library/domain/year_month.dart';
import '../features/search/domain/search_date.dart';

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
  //
  // Months are windowed by *capture date* — the same axis the grid orders and
  // groups by. On Android that is `DATE_TAKEN`; the classic `createTimeCond`
  // filters `DATE_ADDED` (when a file landed on the device) instead, which
  // disagrees with the ordering column and mis-buckets imported photos (a June
  // photo added in July lands in July, and June never appears). So Android uses
  // an `AdvancedCustomFilter` on `datetaken`. iOS's `creationDate` is already
  // consistent across filter/order/report, so it keeps the classic filter.

  bool get _isDarwin => Platform.isIOS || Platform.isMacOS;

  /// Resolves the single "all photos" path for [filter] (newest-first ordering
  /// is baked into the filter), optionally narrowed to a media [type]. Returns
  /// null when the library (for that type) is empty.
  Future<AssetPathEntity?> _path(
    PMFilter filter, {
    RequestType type = RequestType.common,
  }) async {
    final paths = await PhotoManager.getAssetPathList(
      onlyAll: true,
      type: type,
      filterOption: filter,
    );
    return paths.isEmpty ? null : paths.first;
  }

  /// Maps the domain [MediaTypeFilter] onto a `photo_manager` [RequestType],
  /// keeping the plugin type out of the domain/UI layers.
  RequestType _requestType(MediaTypeFilter type) {
    switch (type) {
      case MediaTypeFilter.all:
        return RequestType.common;
      case MediaTypeFilter.photos:
        return RequestType.image;
      case MediaTypeFilter.videos:
        return RequestType.video;
    }
  }

  /// iOS/macOS filter: size-ignoring, newest-first by `creationDate`, optionally
  /// scoped to a `[min, max)` window (inclusive `createTimeCond` bounds).
  FilterOptionGroup _darwinFilter({DateTime? min, DateTime? max}) {
    const assetFilter = FilterOption(
      sizeConstraint: SizeConstraint(ignoreSize: true),
      needTitle: false,
    );
    return FilterOptionGroup(
      imageOption: assetFilter,
      videoOption: assetFilter,
      createTimeCond: (min != null && max != null)
          ? DateTimeCond(min: min, max: max.subtract(const Duration(seconds: 1)))
          : DateTimeCond.def(),
      orders: const [
        OrderOption(type: OrderOptionType.createDate, asc: false),
      ],
    );
  }

  /// Android capture-date (`DATE_TAKEN`) window, newest-first. [min] inclusive,
  /// [max] exclusive; assets with no capture date (`datetaken` null/0) never
  /// match a window — they surface via [olderSummary] instead.
  AdvancedCustomFilter _androidWindow({DateTime? min, DateTime? max}) {
    final col = CustomColumns.android.dateTaken;
    final filter = AdvancedCustomFilter();
    if (min != null) {
      filter.addWhereCondition(
        DateColumnWhereCondition(column: col, operator: '>=', value: min),
      );
    }
    if (max != null) {
      filter.addWhereCondition(
        DateColumnWhereCondition(column: col, operator: '<', value: max),
      );
    }
    return filter..addOrderBy(column: col, isAsc: false);
  }

  /// Android filter for undated assets (`DATE_TAKEN` null/0 — their reported
  /// `createDateTime` falls back to `DATE_ADDED`), newest-added first.
  AdvancedCustomFilter _androidUndated() {
    final taken = CustomColumns.android.dateTaken;
    return AdvancedCustomFilter()
      ..addWhereCondition(
        WhereConditionItem.text('($taken IS NULL OR $taken = 0)'),
      )
      ..addOrderBy(column: CustomColumns.android.createDate, isAsc: false);
  }

  /// The path scoped to one capture-date [month], newest-first.
  Future<AssetPathEntity?> _monthPath(YearMonth month) {
    final filter = _isDarwin
        ? _darwinFilter(min: month.start, max: month.end)
        : _androidWindow(min: month.start, max: month.end);
    return _path(filter);
  }

  /// The descending list of calendar months spanned by *dated* photos. Includes
  /// months with no photos (callers skip empties via [monthSummary]); returns
  /// empty when the library has no dated images. Undated photos are excluded so
  /// they can't stretch the span — they live in the [olderSummary] section.
  Future<List<YearMonth>> monthsInLibrary() async {
    // Android: exclude undated (datetaken >= 1ms). iOS: creationDate is always
    // present, so the plain filter already spans only dated assets.
    final filter = _isDarwin
        ? _darwinFilter()
        : _androidWindow(min: DateTime.fromMillisecondsSinceEpoch(1));
    final path = await _path(filter);
    if (path == null) return const [];
    final count = await path.assetCountAsync;
    if (count == 0) return const [];
    final newest = await path.getAssetListRange(start: 0, end: 1);
    final oldest = await path.getAssetListRange(start: count - 1, end: count);
    if (newest.isEmpty || oldest.isEmpty) return const [];
    _log.fine('Library spans ${newest.first.createDateTime} .. '
        '${oldest.first.createDateTime} ($count dated photos)');
    return YearMonth.descendingRange(
      YearMonth.fromDate(newest.first.createDateTime),
      YearMonth.fromDate(oldest.first.createDateTime),
    );
  }

  /// The exact photo count and up to six newest preview ids for [month], or
  /// null if the month has no photos.
  Future<MonthSummary?> monthSummary(YearMonth month) async {
    final path = await _monthPath(month);
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
    final path = await _monthPath(month);
    if (path == null) return const [];
    final assets = await path.getAssetListPaged(page: page, size: pageSize);
    return [
      for (final a in assets) AssetRef(id: a.id, createdAt: a.createDateTime),
    ];
  }

  /// The exact count and up to six preview ids of undated photos, shown in the
  /// trailing "Older" section, newest-added first. Null on Darwin (creationDate
  /// is always present) or when there are none.
  Future<OlderSummary?> olderSummary() async {
    if (_isDarwin) return null;
    final path = await _path(_androidUndated());
    if (path == null) return null;
    final count = await path.assetCountAsync;
    if (count == 0) return null;
    final preview = await path.getAssetListRange(
      start: 0,
      end: count < 6 ? count : 6,
    );
    return OlderSummary(
      count: count,
      previewAssetIds: [for (final a in preview) a.id],
    );
  }

  /// A page of undated asset references for the "Older" full grid, newest-added
  /// first. Empty on Darwin.
  Future<List<AssetRef>> olderAssets({
    required int page,
    required int pageSize,
  }) async {
    if (_isDarwin) return const [];
    final path = await _path(_androidUndated());
    if (path == null) return const [];
    final assets = await path.getAssetListPaged(page: page, size: pageSize);
    return [
      for (final a in assets) AssetRef(id: a.id, createdAt: a.createDateTime),
    ];
  }

  // --- Search --------------------------------------------------------------

  /// A page of asset references for the metadata Search grid: the library
  /// filtered by media [type] and, when given, a capture-date window
  /// `[min, max)` — newest first. A null window spans the whole library. Uses
  /// the same capture-date axis as the month grid (Android `DATE_TAKEN`, iOS
  /// `creationDate`), so results order and group consistently.
  Future<List<AssetRef>> searchAssets({
    DateTime? min,
    DateTime? max,
    required MediaTypeFilter type,
    required int page,
    required int pageSize,
  }) async {
    final filter =
        _isDarwin ? _darwinFilter(min: min, max: max) : _androidWindow(min: min, max: max);
    final path = await _path(filter, type: _requestType(type));
    if (path == null) return const [];
    final assets = await path.getAssetListPaged(page: page, size: pageSize);
    return [
      for (final a in assets) AssetRef(id: a.id, createdAt: a.createDateTime),
    ];
  }

  /// Filters a bounded set of asset [ids] (the user's favorites) by media
  /// [type] and an optional capture-date window `[min, max)`, newest first.
  /// Favorites live in Drift (not queryable through a `photo_manager` path), so
  /// they are resolved via the cached [_entity] and filtered here rather than
  /// intersected into a paginated path query. Unresolvable ids (e.g. deleted)
  /// are dropped.
  Future<List<AssetRef>> resolveFavoriteMatches({
    required List<String> ids,
    DateTime? min,
    DateTime? max,
    required MediaTypeFilter type,
  }) async {
    final matches = <AssetRef>[];
    for (final id in ids) {
      final entity = await _entity(id);
      if (entity == null) continue;
      if (type == MediaTypeFilter.photos && entity.type != AssetType.image) {
        continue;
      }
      if (type == MediaTypeFilter.videos && entity.type != AssetType.video) {
        continue;
      }
      final created = entity.createDateTime;
      if (min != null && created.isBefore(min)) continue;
      if (max != null && !created.isBefore(max)) continue;
      matches.add(AssetRef(id: id, createdAt: created));
    }
    matches.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return matches;
  }

  // --- Indexing ------------------------------------------------------------

  /// A page of asset ids across the whole library (photos + videos), newest
  /// first — the id-only scan the background indexer walks to find unindexed
  /// assets. Includes undated assets on Android (no capture-date window).
  Future<List<String>> allAssetIds({
    required int page,
    required int pageSize,
  }) async {
    final filter = _isDarwin ? _darwinFilter() : _androidWindow();
    final path = await _path(filter);
    if (path == null) return const [];
    final assets = await path.getAssetListPaged(page: page, size: pageSize);
    return [for (final a in assets) a.id];
  }

  /// The lean metadata the indexer caches in `photo_asset`, or null if the asset
  /// can't be resolved (e.g. deleted). Cheap — reads the cached entity, no file
  /// decode.
  Future<({DateTime createdAt, bool isVideo, int width, int height})?>
      assetIndexMeta(String assetId) async {
    final entity = await _entity(assetId);
    if (entity == null) return null;
    return (
      createdAt: entity.createDateTime,
      isVideo: entity.type == AssetType.video,
      width: entity.width,
      height: entity.height,
    );
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
