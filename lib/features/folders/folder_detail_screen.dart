import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/asset_grid.dart';
import '../../widgets/empty_state.dart';
import 'folders_providers.dart';

/// One device folder's photos (`/folder?id=…&name=…`), reached from the Search
/// screen's Folders section. [folderName] titles the app bar so the screen
/// doesn't have to re-list every folder just to name itself; a deep link that
/// omits it falls back to a generic title.
class FolderDetailScreen extends ConsumerWidget {
  const FolderDetailScreen({
    super.key,
    required this.folderId,
    this.folderName,
  });

  final String folderId;
  final String? folderName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assets = ref.watch(folderAssetsProvider(folderId));

    return Scaffold(
      appBar: AppBar(title: Text(folderName ?? 'Folder')),
      body: assets.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => const EmptyState.note('Couldn\'t load this folder.'),
        data: (items) => items.isEmpty
            ? const EmptyState.note('This folder is empty.')
            : AssetGrid(
                items: items,
                hasMore: ref.watch(folderAssetsProvider(folderId).notifier).hasMore,
                onLoadMore: () =>
                    ref.read(folderAssetsProvider(folderId).notifier).loadMore(),
              ),
      ),
    );
  }
}
