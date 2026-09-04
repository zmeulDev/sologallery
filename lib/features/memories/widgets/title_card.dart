import 'package:flutter/material.dart';

import '../../../core/format/count_labels.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_space.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../widgets/asset_thumbnail.dart';

/// The opening frame: the cover photo, dimmed, with the title over it.
///
/// The cover carries the frame — a text-only card on black reads as a blank
/// screen, not as an opening title. Scrim and bottom-left type block mirror
/// `MemoryCard`, so tapping a card feels like it expanded into the story.
class TitleCard extends StatelessWidget {
  const TitleCard({
    super.key,
    required this.memoryId,
    required this.title,
    required this.subtitle,
    required this.count,
    required this.coverAssetId,
  });

  final int memoryId;
  final String title;
  final String? subtitle;
  final int count;
  final String coverAssetId;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).extension<AppTextStyles>()!;
    return Stack(
      fit: StackFit.expand,
      children: [
        AssetThumbnail(assetId: coverAssetId, size: 1000),
        // Heavier than the card's scrim: the title is larger here and has to
        // hold against a full-bleed photo rather than a 150px thumbnail.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x59000000),
                Color(0x26000000),
                AppOverMedia.scrimDeep,
              ],
              stops: [0, 0.45, 1],
            ),
          ),
        ),
        Positioned(
          left: 28,
          right: 28,
          bottom: 72,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (subtitle case final sub?)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    sub.toUpperCase(),
                    style: text.sectionLabel.copyWith(
                      color: AppOverMedia.glyphSoft,
                    ),
                  ),
                ),
              Text(
                title,
                style: text.pageTitle.copyWith(
                  color: AppOverMedia.glyph,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: AppSpace.s12),
              Text(
                photoCountLabel(count),
                style: text.caption.copyWith(color: AppOverMedia.glyphFaint),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
