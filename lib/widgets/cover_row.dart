import 'package:flutter/material.dart';

import '../core/format/count_labels.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_text_styles.dart';
import 'asset_thumbnail.dart';

/// A compact collection row — cover · name · optional photo count — shared by
/// the Search results (albums, folders) and the add-to-album sheet so every
/// collection list reads as one idiom.
class CoverRow extends StatelessWidget {
  const CoverRow({
    super.key,
    this.coverAssetId,
    required this.name,
    this.count,
    this.fallbackIcon,
    this.showChevron = false,
    required this.onTap,
  });

  /// Null renders the recessed placeholder tile (an empty album, or a folder
  /// whose cover couldn't be resolved), showing [fallbackIcon] if provided.
  final String? coverAssetId;

  final String name;

  /// Trailing photo count; omitted entirely when null.
  final int? count;

  /// Optional glyph centered on the placeholder tile when there is no cover.
  final IconData? fallbackIcon;

  /// Appends a trailing chevron. On for rows that stand alone in a card (device
  /// folders), where nothing else signals the row is a destination; off in a
  /// dense divided list, where a chevron per row is just noise.
  final bool showChevron;

  /// Null disables the row (ink and taps off).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final styles = Theme.of(context).extension<AppTextStyles>()!;
    final scheme = Theme.of(context).colorScheme;
    final cover = coverAssetId;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: AppRadius.br12,
              child: SizedBox(
                width: 44,
                height: 44,
                child: cover == null
                    ? ColoredBox(
                        color: colors.surface2,
                        child: fallbackIcon == null
                            ? null
                            : Center(
                                child: Icon(
                                  fallbackIcon,
                                  size: 20,
                                  color: colors.textMuted,
                                ),
                              ),
                      )
                    : AssetThumbnail(assetId: cover, size: 120),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: styles.body.copyWith(color: scheme.onSurface),
              ),
            ),
            if (count case final n?) ...[
              const SizedBox(width: 8),
              Text(
                photoCountLabel(n),
                style: styles.caption.copyWith(color: colors.textSecondary),
              ),
            ],
            if (showChevron) ...[
              const SizedBox(width: 2),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: colors.textMuted,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
