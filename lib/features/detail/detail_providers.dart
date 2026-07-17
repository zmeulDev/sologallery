import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart' show Album;
import '../../core/database/database_provider.dart';
import '../../services/permission_provider.dart' show photoLibraryServiceProvider;
import '../../services/photo_library_service.dart' show AssetDetail;
import '../library/library_providers.dart';
import '../library/month_assets_provider.dart';

/// Longest-edge cap (px) for the detail preview — sharp on any phone screen,
/// yet small enough to keep a 48MP HEIC from decoding at full size (OOM gotcha).
const kDetailImageMaxEdge = 2048;

/// Full screen-sized preview bytes for one asset, capped at [kDetailImageMaxEdge].
/// `autoDispose` so swiped-away pages release their decoded image. Overridable
/// with deterministic bytes in widget/golden tests.
final detailImageProvider = FutureProvider.autoDispose.family<Uint8List?, String>(
  (ref, assetId) => ref
      .read(photoLibraryServiceProvider)
      .previewImage(assetId, kDetailImageMaxEdge),
);

/// `photo_manager`-native metadata for the EXIF sheet of one asset.
final assetDetailProvider =
    FutureProvider.autoDispose.family<AssetDetail?, String>(
  (ref, assetId) => ref.read(photoLibraryServiceProvider).assetDetail(assetId),
);

/// Whether [assetId] is currently favorited; drives the action-bar heart.
final isFavoriteProvider = StreamProvider.autoDispose.family<bool, String>(
  (ref, assetId) => ref.watch(favoritesDaoProvider).watchIsFavorite(assetId),
);

/// All user albums (for the add-to-album picker), newest sort first.
final albumsListProvider = StreamProvider.autoDispose<List<Album>>(
  (ref) => ref.watch(albumsDaoProvider).watchAllAlbums(),
);

/// Side-effecting detail actions. Kept out of widgets (Riverpod conventions):
/// favoriting, album membership, OS delete + local purge, and OS share.
final detailActionsProvider = Provider<DetailActions>(DetailActions.new);

class DetailActions {
  DetailActions(this._ref);

  final Ref _ref;

  /// Toggles the favorite flag for [assetId].
  Future<void> toggleFavorite(String assetId) async {
    final dao = _ref.read(favoritesDaoProvider);
    if (await dao.isFavorite(assetId)) {
      await dao.remove(assetId);
    } else {
      await dao.add(assetId);
    }
  }

  /// Adds [assetId] to an existing album (idempotent).
  Future<void> addToAlbum(int albumId, String assetId) =>
      _ref.read(albumsDaoProvider).addEntry(albumId, assetId);

  /// Creates a new album and returns its id (for immediately adding to it).
  Future<int> createAlbum(String name) =>
      _ref.read(albumsDaoProvider).createAlbum(name);

  /// Deletes [assetId] from the device library (the OS shows its own trash
  /// dialog) and, if the user confirmed, purges the favorite and album rows and
  /// invalidates the library grids. Returns whether the asset was deleted.
  Future<bool> delete(String assetId) async {
    final deleted =
        await _ref.read(photoLibraryServiceProvider).deleteAssets([assetId]);
    if (!deleted.contains(assetId)) return false;
    await _ref.read(favoritesDaoProvider).remove(assetId);
    await _ref.read(albumsDaoProvider).removeAssetEverywhere(assetId);
    _ref.invalidate(libraryMonthsProvider);
    _ref.invalidate(monthAssetsProvider);
    return true;
  }

  /// Opens the OS share sheet for [assetId]. [origin] anchors the sheet on iPad.
  Future<void> share(String assetId, {Rect? origin}) => _ref
      .read(photoLibraryServiceProvider)
      .shareAssets([assetId], sharePositionOrigin: origin);
}
