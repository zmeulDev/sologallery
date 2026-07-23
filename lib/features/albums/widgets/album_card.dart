import 'package:flutter/material.dart';

import '../../../core/database/daos/albums_dao.dart' show AlbumSummary;
import '../../../core/format/count_labels.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_space.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/asset_thumbnail.dart';

/// One album in the Albums grid: a square cover inside a rounded surface card,
/// with the album name and photo count stacked beneath the cover. Empty albums
/// show a recessed placeholder instead of a cover so the grid still reads as a
/// regular collection tile.
class AlbumCard extends StatelessWidget {
  const AlbumCard({
    super.key,
    required this.summary,
    this.onTap,
    this.onLongPress,
  });

  final AlbumSummary summary;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final text = Theme.of(context).extension<AppTextStyles>()!;
    final scheme = Theme.of(context).colorScheme;
    final cover = summary.coverAssetId;

    return AppCard(
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        behavior: HitTestBehavior.opaque,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: cover == null
                  ? _EmptyCover(colors)
                  : AssetThumbnail(assetId: cover, size: 500),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpace.s12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    summary.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.body.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpace.s4),
                  Text(
                    photoCountLabel(summary.entryCount, zero: 'Empty'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.caption.copyWith(color: colors.textSecondary),
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

class _EmptyCover extends StatelessWidget {
  const _EmptyCover(this.colors);
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: colors.surface2,
      child: Center(
        child: Icon(
          Icons.photo_album_outlined,
          color: colors.textMuted,
          size: 28,
        ),
      ),
    );
  }
}
