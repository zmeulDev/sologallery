import 'dart:io' show File, Platform;
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:flutter/services.dart' show MethodCall;
import 'package:logging/logging.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:share_plus/share_plus.dart';

import '../features/search/domain/search_date.dart';
import 'adjacent_thumbnail_cache.dart';
import 'detail_preview_cache.dart';
import 'thumbnail_gate.dart';

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

/// A pure, plugin-free projection of a `photo_manager` [AssetPathEntity] — one
/// of the folders/collections the device already groups the library into
/// (Android: a MediaStore bucket such as Camera or Screenshots; iOS: a photo
/// album). Surfaced by the Search screen's Folders section; the plugin type
/// never leaves this service (the architecture rule).
class DeviceFolder {
  const DeviceFolder({
    required this.id,
    required this.name,
    required this.count,
    this.coverAssetId,
  });

  /// Android: `MediaStore.Images.Media.BUCKET_ID`. iOS/macOS: the
  /// `PHAssetCollection` local identifier (may contain `/`, so it is routed as
  /// a query parameter rather than a path segment).
  final String id;
  final String name;

  /// Total assets in the folder — the statistic shown next to its name.
  final int count;

  /// The newest asset in the folder, used as the row's cover thumbnail. Null
  /// only if the folder's first page came back empty.
  final String? coverAssetId;
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
}

/// The single wrapper around `photo_manager`. All permission handling, asset
/// and album queries, and thumbnail requests go through here — UI and other
/// layers never import `photo_manager` directly (see docs/spec.md#architecture).
class PhotoLibraryService {
  PhotoLibraryService();

  static final _log = Logger('SoloGallery.photos');
  final _detailPreviewCache = DetailPreviewCache();
  final _adjacentThumbnailCache = AdjacentThumbnailCache();
  final Map<String, Future<Uint8List?>> _previewPending = {};

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

  /// Read access to images and video, **including each photo's EXIF location**.
  ///
  /// `mediaLocation` is what makes `ACCESS_MEDIA_LOCATION` actually get
  /// requested: photo_manager skips it when the option is false (or when the
  /// manifest omits the permission), and without it Android 10+ strips GPS out
  /// of the bytes it hands us, so `latlngAsync()` reports nothing for every
  /// photo and the detail viewer's Location chip is permanently empty.
  static const _permissionOption = PermissionRequestOption(
    androidPermission: AndroidPermission(
      type: RequestType.common,
      mediaLocation: true,
    ),
  );

  /// Current access without prompting the user.
  Future<PhotoAccess> currentAccess() async {
    final state = await PhotoManager.getPermissionState(
      requestOption: _permissionOption,
    );
    _log.fine('Current photo access (no prompt): $state');
    return accessFromState(state);
  }

  /// Prompts for photo access (native dialog). Returns the resulting access.
  Future<PhotoAccess> requestAccess() async {
    final state = await PhotoManager.requestPermissionExtend(
      requestOption: _permissionOption,
    );
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

  // --- Library change notifications ----------------------------------------

  void Function()? _onLibraryChanged;

  void _handleChange(MethodCall _) => _onLibraryChanged?.call();

  /// Registers [onChanged] to fire whenever the device photo library changes
  /// while the app is foregrounded (a new capture, an import, a deletion). Lets
  /// the indexer re-sweep the cache live instead of only on the next resume.
  /// Idempotent — replaces any prior callback.
  Future<void> startLibraryChangeNotify(void Function() onChanged) async {
    _onLibraryChanged = onChanged;
    PhotoManager.addChangeCallback(_handleChange);
    await PhotoManager.startChangeNotify();
    _log.fine('Started library change notifications');
  }

  /// Stops delivering library-change callbacks and clears the registration.
  Future<void> stopLibraryChangeNotify() async {
    PhotoManager.removeChangeCallback(_handleChange);
    await PhotoManager.stopChangeNotify();
    _onLibraryChanged = null;
    _log.fine('Stopped library change notifications');
  }

  // --- Asset queries -------------------------------------------------------
  //
  // The Library/Saved grids read the cached `photo_asset` table (filled by the
  // metadata sweep), not `photo_manager` directly. This service supplies the
  // sweep's source ([libraryMetadataPage]), metadata Search, and thumbnails —
  // full metadata for a whole library is never loaded, and originals are never
  // decoded for grid cells (CLAUDE.md Absolute rules).
  //
  // Assets are windowed by *capture date* — the same axis the grid orders and
  // groups by. On Android that is `DATE_TAKEN`; the classic `createTimeCond`
  // filters `DATE_ADDED` (when a file landed on the device) instead, which
  // disagrees with the ordering column and mis-buckets imported photos (a June
  // photo added in July lands in July, and June never appears). So Android uses
  // an `AdvancedCustomFilter` on `datetaken`, and the sweep tags such assets
  // `is_dated`. iOS's `creationDate` is already consistent across
  // filter/order/report, so it keeps the classic filter.

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
  /// match a window — [libraryMetadataPage] surfaces them as the undated set
  /// (cached with `is_dated = false`) instead.
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
    return filter..addOrderBy(column: _androidCaptureOrder, isAsc: false);
  }

  /// The date axis to order Android queries by: capture date where there is
  /// one, date-added otherwise — in seconds, since `datetaken` is milliseconds
  /// and `date_added` seconds (`NULLIF` because undated assets carry `0`, not
  /// only `NULL`).
  ///
  /// This is deliberately the same expression `photo_manager` reports as
  /// [AssetEntity.createDateTime], which falls back to `DATE_ADDED` the same
  /// way. Ordering by bare `datetaken` instead puts undated assets last (SQLite
  /// sorts NULLs last on `DESC`) while they still *report* a recent date, so a
  /// folder grid trails photos dated newer than everything above them —
  /// `device_folders_test` catches exactly that. Windowed queries are
  /// unaffected: their `WHERE` already excludes undated assets, and for a dated
  /// asset the expression is just `datetaken` in seconds.
  static const _androidCaptureOrder =
      'COALESCE(NULLIF(datetaken, 0) / 1000, date_added)';

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

  // --- Device folders ------------------------------------------------------

  /// Resolved folder paths keyed by [DeviceFolder.id], filled by
  /// [deviceFolders]. `photo_manager` has no cheap "path from id" that accepts
  /// the Android [AdvancedCustomFilter] this service relies on
  /// ([AssetPathEntity.fromId] takes a [FilterOptionGroup] only), so
  /// [folderAssets] pages against the cached entity instead of re-listing every
  /// folder for each page.
  final Map<String, AssetPathEntity> _pathCache = {};

  /// Lists every folder/collection the device groups the library into, with its
  /// asset count and a cover asset — the Search screen's Folders section.
  /// Sorted by [DeviceFolder.count] descending (name ascending to break ties);
  /// empty folders are dropped.
  ///
  /// Uses the same capture-date filter split as the grids ([_darwinFilter] /
  /// [_androidWindow] with no window), so each folder's cover is its newest
  /// asset. On Android the unbounded window is just an ordering — assets with
  /// no `DATE_TAKEN` still belong to the folder and sort by their `DATE_ADDED`
  /// instead (see [_androidCaptureOrder]), the same date they report, so the
  /// cover is the newest by the date the grid actually shows.
  Future<List<DeviceFolder>> deviceFolders() async {
    final paths = await PhotoManager.getAssetPathList(
      hasAll: false, // Skip the synthetic "Recent"/all-photos album.
      onlyAll: false,
      type: RequestType.common,
      filterOption: _isDarwin ? _darwinFilter() : _androidWindow(),
    );

    final folders = <DeviceFolder>[];
    for (final path in paths) {
      // On iOS `albumType` 2 is a *folder of albums* — a container that holds no
      // assets of its own. Android is always 1.
      if (_isDarwin && path.albumType != 1) continue;

      final count = await path.assetCountAsync;
      if (count == 0) continue;

      final first = await path.getAssetListPaged(page: 0, size: 1);
      _pathCache[path.id] = path;
      folders.add(
        DeviceFolder(
          id: path.id,
          name: path.name,
          count: count,
          coverAssetId: first.isEmpty ? null : first.first.id,
        ),
      );
    }

    folders.sort((a, b) {
      final byCount = b.count.compareTo(a.count);
      return byCount != 0 ? byCount : a.name.compareTo(b.name);
    });
    _log.fine('Listed ${folders.length} device folder(s)');
    return folders;
  }

  /// A page of asset references from the folder [folderId], newest first —
  /// the folder detail grid. Returns an empty page once exhausted, or if the
  /// folder no longer exists (e.g. its last photo was deleted).
  Future<List<AssetRef>> folderAssets({
    required String folderId,
    required int page,
    required int pageSize,
  }) async {
    var path = _pathCache[folderId];
    if (path == null) {
      // Cold start (deep link / restore) — refill the cache, then retry once.
      await deviceFolders();
      path = _pathCache[folderId];
    }
    if (path == null) {
      _log.warning('No device folder for id $folderId');
      return const [];
    }
    final assets = await path.getAssetListPaged(page: page, size: pageSize);
    return [
      for (final a in assets) AssetRef(id: a.id, createdAt: a.createDateTime),
    ];
  }

  // --- Indexing ------------------------------------------------------------

  /// A page of lean per-asset metadata for the fast metadata sweep — the axis
  /// that fills the `photo_asset` cache before ML runs. [dated] selects the
  /// dated window (capture-date present) or, on Android, the undated set; the
  /// undated set is always empty on Darwin (`creationDate` is always present).
  /// Metadata comes inline from the paged query — no per-asset entity round-trip.
  Future<List<({String id, DateTime createdAt, bool isVideo, int width, int height})>>
      libraryMetadataPage({
    required bool dated,
    required int page,
    required int pageSize,
  }) async {
    final PMFilter? filter;
    if (dated) {
      filter = _isDarwin
          ? _darwinFilter()
          : _androidWindow(min: DateTime.fromMillisecondsSinceEpoch(1));
    } else {
      filter = _isDarwin ? null : _androidUndated();
    }
    if (filter == null) return const []; // Darwin has no undated assets.
    final path = await _path(filter);
    if (path == null) return const [];
    final assets = await path.getAssetListPaged(page: page, size: pageSize);
    return [
      for (final a in assets)
        (
          id: a.id,
          createdAt: a.createDateTime,
          isVideo: a.type == AssetType.video,
          width: a.width,
          height: a.height,
        ),
    ];
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

  /// Caps concurrent grid-thumbnail decodes and discards ones whose cell has
  /// scrolled away — see [ThumbnailGate]. [previewImage] deliberately does not
  /// go through it: the detail viewer asks for one large image (plus its ±3
  /// neighbours) and must not queue behind a grid fling's backlog.
  final ThumbnailGate _thumbnailGate = ThumbnailGate();

  /// A separate, smaller pool for indexing's own thumbnails. A pass requests
  /// one 512 (and optionally one 1024 OCR) thumbnail per asset, sequentially,
  /// so it never needs more than a slot or two — but sharing the grid's 6-slot
  /// gate meant a pass starved scrolling to 5 during indexing. Its own pool
  /// keeps the grid's slots reserved for the grid and the pass's for the pass.
  final ThumbnailGate _indexingGate = ThumbnailGate(maxConcurrent: 3);

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
  /// resolved (e.g. deleted) or [cancelled] reported the caller gave up while
  /// the request was queued. Never decodes the original at full size
  /// (Absolute rules) — the detail viewer requests a screen-capped size, the
  /// grid a cell-sized one.
  ///
  /// Pass [indexing] true for the background indexer's own thumbnails so they
  /// use a separate pool ([_indexingGate]) and don't take slots from the grid's
  /// gate mid-fling.
  Future<Uint8List?> thumbnail(
    String assetId,
    int width,
    int height, {
    bool Function()? cancelled,
    bool indexing = false,
  }) {
    final gate = indexing ? _indexingGate : _thumbnailGate;
    return gate.run(() async {
      final entity = await _entity(assetId);
      if (entity == null) return null;
      return entity.thumbnailDataWithSize(ThumbnailSize(width, height));
    }, cancelled: cancelled);
  }

  /// A high-quality, screen-sized preview for the detail viewer — the whole
  /// image, uncropped, capped at [maxEdge] px on its longest side. Uses `fit`
  /// resize on iOS (the plain [thumbnailDataWithSize] hardcodes `fill`, which
  /// would crop); Android's scaler already fits within the box. The cap keeps a
  /// 48MP HEIC from decoding at full size (the OOM gotcha) while staying far
  /// sharper than a grid thumbnail. Never the full original (Absolute rules).
  ///
  /// Results are cached in a small in-memory LRU so revisiting the same photo
  /// during a session is instant; call [clearDetailPreviewCache] on lifecycle
  /// pause or memory pressure to reclaim the RAM. Concurrent requests for the
  /// same key share one underlying fetch.
  Future<Uint8List?> previewImage(String assetId, int maxEdge) {
    final cached = _detailPreviewCache.get(assetId, maxEdge);
    if (cached != null) {
      _log.fine('previewImage($assetId, ${maxEdge}px) cache hit');
      return Future.value(cached);
    }

    final key = '$assetId:$maxEdge';
    final pending = _previewPending[key];
    if (pending != null) {
      _log.fine('previewImage($assetId, ${maxEdge}px) pending dedupe');
      return pending;
    }

    final future = _fetchPreviewImage(assetId, maxEdge);
    _previewPending[key] = future;
    future.whenComplete(() => _previewPending.remove(key));
    return future;
  }

  Future<Uint8List?> _fetchPreviewImage(String assetId, int maxEdge) async {
    final total = Stopwatch()..start();
    final entityTimer = Stopwatch()..start();
    final entity = await _entity(assetId);
    entityTimer.stop();
    if (entity == null) {
      total.stop();
      _detailPreviewCache.put(assetId, maxEdge, null);
      _log.fine(
        'previewImage($assetId) entity unresolved after '
        '${entityTimer.elapsedMilliseconds}ms',
      );
      return null;
    }
    final size = ThumbnailSize.square(maxEdge);
    final option = (Platform.isIOS || Platform.isMacOS)
        ? ThumbnailOption.ios(
            size: size,
            quality: 95,
            resizeContentMode: ResizeContentMode.fit,
          )
        : ThumbnailOption(size: size, quality: 95);
    final thumbTimer = Stopwatch()..start();
    final bytes = await entity.thumbnailDataWithOption(option);
    thumbTimer.stop();
    total.stop();
    _detailPreviewCache.put(assetId, maxEdge, bytes);
    _log.fine(
      'previewImage($assetId, ${maxEdge}px) '
      'entity=${entityTimer.elapsedMilliseconds}ms '
      'thumb=${thumbTimer.elapsedMilliseconds}ms '
      'total=${total.elapsedMilliseconds}ms '
      'bytes=${bytes?.length ?? 0}',
    );
    return bytes;
  }

  /// A small, fast thumbnail for the detail viewer's adjacent pages. Capped at
  /// [maxEdge] px on its longest side, it is meant as an instant placeholder
  /// while the larger [previewImage] decodes. Results are cached in a tiny LRU
  /// so swiping back and forth between the same neighbours is instant.
  ///
  /// This deliberately does not go through [thumbnail] / [ThumbnailGate]: the
  /// detail viewer issues a bounded number of these (≤15) and iOS needs
  /// `ResizeContentMode.fit` to avoid square-cropping the placeholder.
  Future<Uint8List?> adjacentThumbnail(String assetId, int maxEdge) async {
    final cached = _adjacentThumbnailCache.get(assetId);
    if (cached != null) {
      _log.fine('adjacentThumbnail($assetId) cache hit');
      return cached;
    }
    if (_adjacentThumbnailCache.contains(assetId)) {
      _log.fine('adjacentThumbnail($assetId) cache hit (null)');
      return null;
    }

    final sw = Stopwatch()..start();
    final bytes = await _fetchAdjacentThumbnail(assetId, maxEdge);
    sw.stop();
    _adjacentThumbnailCache.put(assetId, bytes);
    _log.fine(
      'adjacentThumbnail($assetId, ${maxEdge}px) fetched in '
      '${sw.elapsedMilliseconds}ms bytes=${bytes?.length ?? 0}',
    );
    return bytes;
  }

  Future<Uint8List?> _fetchAdjacentThumbnail(String assetId, int maxEdge) async {
    final entity = await _entity(assetId);
    if (entity == null) return null;
    final size = ThumbnailSize.square(maxEdge);
    final option = (Platform.isIOS || Platform.isMacOS)
        ? ThumbnailOption.ios(
            size: size,
            quality: 90,
            resizeContentMode: ResizeContentMode.fit,
          )
        : ThumbnailOption(size: size, quality: 90);
    return entity.thumbnailDataWithOption(option);
  }

  /// Drops the in-memory adjacent thumbnail cache. Call from lifecycle pause
  /// and memory-pressure handlers to keep background RAM low.
  void clearAdjacentThumbnailCache() {
    _adjacentThumbnailCache.clear();
  }

  /// Drops the in-memory detail preview cache and any in-flight dedupe futures.
  /// Call from lifecycle pause and memory-pressure handlers to keep background
  /// RAM low.
  void clearDetailPreviewCache() {
    _detailPreviewCache.clear();
    _previewPending.clear();
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
