import 'package:flutter/material.dart';

import '../../../core/theme/app_space.dart';
import '../../../core/theme/app_text_styles.dart';
import 'preview_grid.dart';
import 'section_count_pill.dart';

/// One Library section: a labelled header with a count pill that opens the full
/// grid, over a preview grid. Backs calendar-day sections and the "Older" bucket.
class LibrarySection extends StatelessWidget {
  const LibrarySection({
    super.key,
    required this.label,
    required this.count,
    required this.previewAssetIds,
    this.onViewAll,
  });

  final String label;
  final int count;
  final List<String> previewAssetIds;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    final styles = Theme.of(context).extension<AppTextStyles>()!;
    final scheme = Theme.of(context).colorScheme;

    final header = Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.s8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label.toUpperCase(),
              style: styles.sectionLabel.copyWith(color: scheme.onSurface),
            ),
          ),
          SectionCountPill(count: count, showChevron: onViewAll != null),
        ],
      ),
    );

    return Padding(
      // The whole gap between two sections lives on the top edge. Splitting it
      // across a top *and* a bottom pad makes the visible gap their sum, which
      // is how it drifted to 36px and read as a break rather than a rhythm.
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s8,
        AppSpace.s20,
        AppSpace.s8,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (onViewAll != null)
            Semantics(
              button: true,
              child: GestureDetector(
                // The row is mostly whitespace; without this only the label's
                // glyphs would answer a tap.
                behavior: HitTestBehavior.opaque,
                onTap: onViewAll,
                child: header,
              ),
            )
          else
            header,
          const SizedBox(height: 10),
          PreviewGrid(assetIds: previewAssetIds),
        ],
      ),
    );
  }
}
