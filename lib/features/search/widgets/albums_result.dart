import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/daos/albums_dao.dart' show AlbumSummary;
import '../../../core/format/count_labels.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_space.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../widgets/asset_thumbnail.dart';
import '../../../widgets/section_header.dart';

/// Matching albums as a short horizontal scroller of cover chips, so the
/// section is compact and never pushes the photo grid off screen.
class AlbumsResult extends StatelessWidget {
  const AlbumsResult({super.key, required this.albums});

  final List<AlbumSummary> albums;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: SectionHeader(label: 'Albums'),
        ),
        SizedBox(
          height: 128,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.s16),
            itemCount: albums.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpace.s12),
            itemBuilder: (context, index) => _AlbumTile(album: albums[index]),
          ),
        ),
      ],
    );
  }
}

/// One album in the horizontal results scroller: square cover, name, count.
class _AlbumTile extends StatelessWidget {
  const _AlbumTile({required this.album});

  final AlbumSummary album;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final styles = Theme.of(context).extension<AppTextStyles>()!;
    final scheme = Theme.of(context).colorScheme;
    final cover = album.coverAssetId;

    return GestureDetector(
      onTap: () => context.push('/album/${album.id}'),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 84,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: AppRadius.br12,
              child: SizedBox(
                width: 84,
                height: 84,
                child: cover == null
                    ? ColoredBox(
                        color: colors.surface2,
                        child: Center(
                          child: Icon(
                            Icons.photo_album_outlined,
                            size: 28,
                            color: colors.textMuted,
                          ),
                        ),
                      )
                    : AssetThumbnail(assetId: cover, size: 256),
              ),
            ),
            const SizedBox(height: AppSpace.s8),
            Text(
              album.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: styles.caption.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              photoCountLabel(album.entryCount, zero: 'Empty'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: styles.caption.copyWith(color: colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
