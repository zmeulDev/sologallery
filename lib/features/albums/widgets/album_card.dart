import 'package:flutter/material.dart';

import '../../../core/database/daos/albums_dao.dart' show AlbumSummary;
import '../../../core/format/count_labels.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../widgets/asset_thumbnail.dart';
import '../../../widgets/pressable.dart';

/// One album in the Albums grid: a square cover with the name and photo count
/// set quietly beneath it. The cover photo is the only color; the label chrome
/// stays neutral, matching the rest of the app. An empty album shows a recessed
/// placeholder instead of a cover.
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

    return Pressable(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The cover flexes to fill the space above the labels — near-square in
          // the 2-col grid, and never overflows a slightly short cell.
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: double.infinity,
                child: cover == null
                    ? _EmptyCover(colors)
                    : AssetThumbnail(assetId: cover, size: 500),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            summary.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.body.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            photoCountLabel(summary.entryCount, zero: 'Empty'),
            style: text.caption.copyWith(color: colors.textSecondary),
          ),
        ],
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
        child: Icon(Icons.photo_album_outlined, color: colors.textMuted, size: 28),
      ),
    );
  }
}
