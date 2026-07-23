import 'package:flutter/material.dart';

import '../../../core/database/daos/albums_dao.dart' show AlbumSummary;
import '../../../core/format/count_labels.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_space.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/asset_thumbnail.dart';

/// One album as a compact horizontal row: a square padded cover on the left and
/// the album name + photo count stacked on the right. The card and cover both
/// use the navbar-matched 30 dp radius. Empty albums show a recessed placeholder
/// so the row still reads as a regular collection item.
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

  /// Height of the cover thumbnail. Kept compact so dense album libraries
  /// fit two columns comfortably on phones.
  static const double _coverSize = 56;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final text = Theme.of(context).extension<AppTextStyles>()!;
    final scheme = Theme.of(context).colorScheme;
    final cover = summary.coverAssetId;

    return AppCard(
      borderRadius: AppRadius.br30,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.s12,
            vertical: AppSpace.s8,
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: AppRadius.br30,
                child: SizedBox(
                  width: _coverSize,
                  height: _coverSize,
                  child: cover == null
                      ? _EmptyCover(colors)
                      : AssetThumbnail(assetId: cover, size: 256),
                ),
              ),
              const SizedBox(width: AppSpace.s24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
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
