import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_space.dart';

/// The story's spine: one segment per page, filled up to the current one. The
/// same motif the memory card previews.
class Progress extends StatelessWidget {
  const Progress({
    super.key,
    required this.pages,
    required this.index,
    required this.paused,
  });

  final int pages;
  final int index;
  final bool paused;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: AppSpace.s16,
      right: AppSpace.s16,
      child: Opacity(
        // Dimming the whole bar is the only "paused" signal — no icon, no
        // overlay covering the photo you paused to look at.
        opacity: paused ? 0.35 : 1,
        child: Row(
          children: [
            for (var i = 0; i < pages; i++) ...[
              if (i > 0) const SizedBox(width: 3),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: i <= index
                        ? AppOverMedia.glyph
                        : AppOverMedia.segmentOff,
                    borderRadius: const BorderRadius.all(Radius.circular(1)),
                  ),
                  child: const SizedBox(height: 2),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
