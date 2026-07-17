import 'dart:typed_data';

import 'package:logging/logging.dart';
import 'package:photo_manager/photo_manager.dart';

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
    final filter = FilterOptionGroup(
      imageOption: const FilterOption(
        sizeConstraint: SizeConstraint(ignoreSize: true),
        needTitle: false,
      ),
      createTimeCond: (min != null && max != null)
          ? DateTimeCond(min: min, max: max)
          : DateTimeCond.def(),
      orders: const [
        OrderOption(type: OrderOptionType.createDate, asc: false),
      ],
    );
    final paths = await PhotoManager.getAssetPathList(
      onlyAll: true,
      type: RequestType.image,
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

  /// Cache of resolved [AssetEntity]s so repeated thumbnail requests for the
  /// same id skip the `AssetEntity.fromId` round-trip. `photo_manager` caches
  /// the thumbnail bytes themselves natively.
  final Map<String, AssetEntity> _entityCache = {};

  /// A `width`×`height` thumbnail for [assetId], or null if the asset can't be
  /// resolved (e.g. deleted). Never decodes the original at full size
  /// (Absolute rules).
  Future<Uint8List?> thumbnail(String assetId, int width, int height) async {
    var entity = _entityCache[assetId];
    if (entity == null) {
      entity = await AssetEntity.fromId(assetId);
      if (entity == null) return null;
      _entityCache[assetId] = entity;
    }
    return entity.thumbnailDataWithSize(ThumbnailSize(width, height));
  }
}
