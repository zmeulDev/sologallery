import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/format/count_labels.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_space.dart';
import '../core/theme/app_text_styles.dart';
import '../services/photo_library_service.dart' show DeviceFolder;

/// The device's folders, two to a row, each linking to its `/folder` grid.
/// Renders nothing when there are no folders, so callers can drop it into a list
/// unconditionally.
///
/// **This is a sliver** — place it directly in a `CustomScrollView`, never
/// inside a `SliverToBoxAdapter`. It used to be a `shrinkWrap`ped `GridView`,
/// which laid out against unbounded extent and so built *every* tile up front
/// to discover its own height. As a real sliver the enclosing viewport gives
/// it a bounded extent and only on-screen tiles build.
///
/// Each tile is a compact chip: a subtle `surface2` rounded rectangle with a
/// small folder glyph, the folder name, and a compact photo count. No cover
/// photo — device folders are picked by name (`Camera`, `Screenshots`), so the
/// chrome stays quiet and the section does not compete with the Albums grid.
class FolderList extends StatelessWidget {
  const FolderList({super.key, required this.folders});

  final List<DeviceFolder> folders;

  /// The chip's natural height. A compact row that still grows with text scale
  /// so large-type users never clip the label.
  static double tileHeight(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final styles = Theme.of(context).extension<AppTextStyles>()!;
    final labelHeight = scaler.scale(styles.body.fontSize ?? 14) * 1.3;
    final content = math.max(_iconSize, labelHeight);
    return math.max(_tileHeightMin, content + AppSpace.s12 * 2);
  }

  @override
  Widget build(BuildContext context) {
    if (folders.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s16,
        0,
        AppSpace.s16,
        AppSpace.s8,
      ),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: AppSpace.s12,
          crossAxisSpacing: AppSpace.s12,
          mainAxisExtent: tileHeight(context),
        ),
        delegate: SliverChildBuilderDelegate(
          (context, i) => _FolderChip(folder: folders[i]),
          childCount: folders.length,
        ),
      ),
    );
  }
}

const double _tileHeightMin = 40;
const double _iconSize = 18;

/// One device folder: a tappable compact chip with a small folder glyph, name,
/// and compact photo-count label on a subtle surface background.
class _FolderChip extends StatelessWidget {
  const _FolderChip({required this.folder});

  final DeviceFolder folder;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final styles = Theme.of(context).extension<AppTextStyles>()!;
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () => context.push(
        Uri(
          path: '/folder',
          queryParameters: {'id': folder.id, 'name': folder.name},
        ).toString(),
      ),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s12,
          vertical: AppSpace.s8,
        ),
        decoration: ShapeDecoration(
          color: colors.surface2,
          shape: const StadiumBorder(),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_rounded,
              size: _iconSize,
              color: colors.textSecondary,
            ),
            const SizedBox(width: AppSpace.s8),
            Expanded(
              child: Text(
                folder.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: styles.body.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: AppSpace.s8),
            Text(
              compactCount(folder.count),
              maxLines: 1,
              style: styles.caption.copyWith(color: colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
