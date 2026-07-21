import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_space.dart';
import '../services/photo_library_service.dart' show DeviceFolder;
import 'app_card.dart';
import 'cover_row.dart';

/// The device's folders, each in its own card, linking to its `/folder` grid.
/// Renders nothing when there are no folders, so callers can drop it into a list
/// unconditionally.
///
/// Carded rather than a flat divided list because folders are the app's one
/// *foreign* collection — they come from the filesystem, not from anything the
/// user did in here. Separating them into discrete cards keeps them from reading
/// as a continuation of the albums above.
class FolderList extends StatelessWidget {
  const FolderList({super.key, required this.folders});

  final List<DeviceFolder> folders;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final folder in folders)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.s16,
              0,
              AppSpace.s16,
              AppSpace.s8,
            ),
            child: AppCard(
              child: CoverRow(
                coverAssetId: folder.coverAssetId,
                name: folder.name,
                count: folder.count,
                fallbackIcon: Icons.folder_outlined,
                showChevron: true,
                onTap: () => context.push(
                  Uri(
                    path: '/folder',
                    queryParameters: {'id': folder.id, 'name': folder.name},
                  ).toString(),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
