import 'package:flutter/material.dart';

import '../../../core/database/daos/memories_dao.dart' show MemorySummary;
import '../../../core/format/count_labels.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../widgets/asset_thumbnail.dart';
import '../../../widgets/pressable.dart';
import '../domain/memory_kind.dart';
import '../memory_hero_tag.dart';

/// One memory in the Library carousel: a portrait cover with its title set
/// over the photo, and a row of hairline segments marking how many photos the
/// story holds.
///
/// Deliberately unlike `AlbumCard`, which sets its label *below* a square
/// cover: an album is a container you file things into, a memory is a story
/// you play. Overlaying the title makes the card read as a poster, and the
/// segment row previews the player's progress bar — the same motif in both
/// places, carrying real information (length) rather than decoration.
class MemoryCard extends StatelessWidget {
  const MemoryCard({
    super.key,
    required this.memory,
    this.onTap,
    this.onLongPress,
  });

  final MemorySummary memory;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Card width in the horizontal strip; the height comes from [aspectRatio].
  static const width = 150.0;

  /// Portrait, like a story frame rather than an album's square.
  static const aspectRatio = 3 / 4;

  /// More segments than this reads as noise at card size.
  static const _maxSegments = 12;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final text = Theme.of(context).extension<AppTextStyles>()!;
    final cover = memory.coverAssetId;

    return Semantics(
      button: true,
      label: '${memory.title}, ${photoCountLabel(memory.assetCount)}',
      child: Pressable(
        onTap: onTap,
        onLongPress: onLongPress,
        child: SizedBox(
          width: width,
          child: AspectRatio(
            aspectRatio: aspectRatio,
            child: ClipRRect(
              borderRadius: AppRadius.br12,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (cover == null)
                    ColoredBox(color: colors.surface2)
                  else
                    Hero(
                      tag: memoryHeroTag(memory.id),
                      child: AssetThumbnail(assetId: cover, size: 500),
                    ),
                  // Ink from the bottom so the title stays legible over any
                  // photo, in either theme.
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.center,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x00000000), AppOverMedia.scrimHeavy],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 10,
                    right: 10,
                    top: 10,
                    child: _Segments(count: memory.assetCount),
                  ),
                  Positioned(
                    left: 10,
                    right: 10,
                    bottom: 10,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Says what *sort* of memory this is, above the title
                        // that says which one. Silent for a kind this build
                        // doesn't recognise rather than showing a raw enum name.
                        if (memoryKindFromName(memory.kind) case final kind?)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: Text(
                              kind.label.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.sectionLabel.copyWith(
                                color: AppOverMedia.glyphSoft,
                              ),
                            ),
                          ),
                        Text(
                          memory.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: text.body.copyWith(
                            color: AppOverMedia.glyph,
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                          ),
                        ),
                        if (memory.subtitle case final sub?) ...[
                          const SizedBox(height: 2),
                          Text(
                            sub,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.caption.copyWith(
                              color: AppOverMedia.glyphSoft,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A hairline segment per photo — the story's length, at a glance. Echoes the
/// player's progress bar so the card and the thing it opens share a motif.
class _Segments extends StatelessWidget {
  const _Segments({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final shown = count.clamp(1, MemoryCard._maxSegments);
    return Row(
      children: [
        for (var i = 0; i < shown; i++) ...[
          if (i > 0) const SizedBox(width: 3),
          const Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppOverMedia.segment,
                borderRadius: BorderRadius.all(Radius.circular(1)),
              ),
              child: SizedBox(height: 2),
            ),
          ),
        ],
      ],
    );
  }
}
