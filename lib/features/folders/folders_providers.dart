import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/paged_assets_notifier.dart';
import '../../services/permission_provider.dart';
import '../../services/photo_library_service.dart';

/// The device's folders (Android MediaStore buckets, iOS albums) with their
/// asset counts, newest-cover first — the Albums screen's idle Folders section.
/// One-shot: the list is cheap enough to rebuild when the screen is reopened,
/// and folder membership only changes when the library does.
final deviceFoldersProvider = FutureProvider.autoDispose<List<DeviceFolder>>(
  (ref) => ref.read(photoLibraryServiceProvider).deviceFolders(),
);

/// One folder's assets, paged newest-first. Pages `photo_manager` directly
/// rather than the Drift cache (a folder isn't a cached axis), so this extends
/// the one-shot [PagedAssetsNotifier] rather than the reactive
/// `WatchedAssetsNotifier` the Library grids use.
class FolderAssetsNotifier extends PagedAssetsNotifier {
  FolderAssetsNotifier(this.folderId);

  final String folderId;

  @override
  Future<List<AssetRef>> fetchPage(int page, int pageSize) =>
      ref.read(photoLibraryServiceProvider).folderAssets(
            folderId: folderId,
            page: page,
            pageSize: pageSize,
          );
}

final folderAssetsProvider = AsyncNotifierProvider.autoDispose
    .family<FolderAssetsNotifier, List<AssetRef>, String>(
  FolderAssetsNotifier.new,
);
