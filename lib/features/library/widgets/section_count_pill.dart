import 'package:flutter/material.dart';

import '../../../core/format/count_labels.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_space.dart';
import '../../../core/theme/app_text_styles.dart';

/// A quiet count pill that signals a tappable section header.
///
/// The pill is purely visual — the surrounding header row is the actual tap
/// target — and uses the same recessed surface as inactive filter pills so it
/// reads as a secondary affordance, not a primary button. It shows the count
/// and, when [showChevron] is true, a trailing arrow that hints the row opens
/// the full grid.
class SectionCountPill extends StatelessWidget {
  const SectionCountPill({
    super.key,
    required this.count,
    this.showChevron = true,
  });

  final int count;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final styles = Theme.of(context).extension<AppTextStyles>()!;
    return Container(
      decoration: ShapeDecoration(
        color: colors.surface2,
        shape: const StadiumBorder(),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s8,
        AppSpace.s4,
        AppSpace.s4,
        AppSpace.s4,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            itemCountLabel(count),
            style: styles.caption.copyWith(color: colors.textSecondary),
          ),
          if (showChevron) ...[
            const SizedBox(width: AppSpace.s2),
            Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: colors.textMuted,
            ),
          ],
        ],
      ),
    );
  }
}
