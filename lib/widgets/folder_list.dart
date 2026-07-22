import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/format/count_labels.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_space.dart';
import '../core/theme/app_text_styles.dart';
import '../services/photo_library_service.dart' show DeviceFolder;
import 'asset_thumbnail.dart';
import 'pressable.dart';

/// The device's folders, two to a row, each linking to its `/folder` grid.
/// Renders nothing when there are no folders, so callers can drop it into a list
/// unconditionally.
///
/// **This is a sliver** — place it directly in a `CustomScrollView`, never
/// inside a `SliverToBoxAdapter`. It used to be a `shrinkWrap`ped `GridView`,
/// which laid out against unbounded extent and so built *every* tile up front
/// to discover its own height. Each tile blurs its cover
/// ([ImageFilter.blur] at sigma 18), so on a device with 30-odd folders that
/// meant thirty thumbnail decodes and thirty Gaussian passes on the first frame
/// of the Albums screen regardless of how many were visible. As a real sliver
/// the enclosing viewport gives it a bounded extent and only on-screen tiles
/// build.
///
/// A folder tile is a *row*, not a picture with a caption: the cover sits behind
/// the label as a blurred backdrop and the folder glyph is what the eye lands
/// on. That matches how these are picked — by name (`Camera`, `Screenshots`),
/// because they come from the filesystem rather than from anything the user did
/// in here. An album, which the user made and recognizes by its cover, keeps the
/// tall sharp-cover card.
class FolderList extends StatelessWidget {
  const FolderList({super.key, required this.folders});

  final List<DeviceFolder> folders;

  /// The row's height. Fixed rather than derived from an aspect ratio — a row's
  /// height comes from its content, not its width — but it still has to grow
  /// with the text scale or the two label lines are squashed by a tight box.
  static double tileHeight(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final styles = Theme.of(context).extension<AppTextStyles>()!;
    final labels =
        scaler.scale(styles.body.fontSize ?? 14) * 1.3 * 2 + // name, 2 lines
        2 +
        scaler.scale(styles.caption.fontSize ?? 11) * 1.3; // count
    return math.max(96, math.max(_glyphSize, labels) + AppSpace.s12 * 2);
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
          crossAxisSpacing: AppSpace.s16,
          mainAxisExtent: tileHeight(context),
        ),
        delegate: SliverChildBuilderDelegate(
          (context, i) => _FolderTile(folder: folders[i]),
          childCount: folders.length,
        ),
      ),
    );
  }
}

/// The folder mark, big enough to be the tile's anchor.
const double _glyphSize = 32;

/// One device folder: the folder glyph, then the name and count, over the
/// blurred cover.
class _FolderTile extends StatelessWidget {
  const _FolderTile({required this.folder});

  final DeviceFolder folder;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final styles = Theme.of(context).extension<AppTextStyles>()!;
    final scheme = Theme.of(context).colorScheme;
    final cover = folder.coverAssetId;

    // A folder with no cover has nothing to blur, so it falls back to a plain
    // recessed surface — and then carries theme colors, not the over-media
    // whites, since there is no photo underneath them.
    final glyphColor = cover == null ? colors.textMuted : AppOverMedia.glyph;
    final nameColor = cover == null ? scheme.onSurface : AppOverMedia.glyph;
    final countColor = cover == null
        ? colors.textSecondary
        : AppOverMedia.glyphSoft;

    return Pressable(
      onTap: () => context.push(
        Uri(
          path: '/folder',
          queryParameters: {'id': folder.id, 'name': folder.name},
        ).toString(),
      ),
      child: ClipRRect(
        borderRadius: AppRadius.br12,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (cover == null)
              ColoredBox(color: colors.surface2)
            else ...[
              // ImageFiltered filters the layer the thumbnail already draws
              // into (no saveLayer, unlike BackdropFilter), and the default
              // clamp tile mode extends the edge pixels so the blur leaves no
              // transparent halo inside the rounded clip.
              ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: AssetThumbnail(assetId: cover),
              ),
              const ColoredBox(color: AppOverMedia.scrim),
            ],
            Padding(
              padding: const EdgeInsets.all(AppSpace.s12),
              child: Row(
                children: [
                  Icon(
                    Icons.folder_rounded,
                    size: _glyphSize,
                    color: glyphColor,
                  ),
                  const SizedBox(width: AppSpace.s12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Two lines: the text column is only ~90px wide in a
                        // 2-up cell, so a name like "Screenshots" needs to wrap
                        // rather than ellipsize away to nothing.
                        Text(
                          folder.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: styles.body.copyWith(
                            color: nameColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          photoCountLabel(folder.count),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: styles.caption.copyWith(color: countColor),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
