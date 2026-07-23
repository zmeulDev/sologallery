import 'package:flutter/material.dart';

import '../../../core/format/count_labels.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_space.dart';
import '../../../core/theme/app_text_styles.dart';
import '../domain/year_month.dart';

/// A sentence-case header for one calendar month in the Library timeline.
///
/// The month name is set at 18 / 700 — smaller than the app-bar page title so
/// year heroes stay the dominant voice, but still heavy enough to read as a
/// section boundary against the 11sp uppercase [SectionHeader] used elsewhere.
/// The exact count trails on the same baseline in the quiet caption style. The
/// whole row is tappable when [onTap] is provided, growing a chevron to match
/// [SectionHeader]'s affordance.
class MonthHeader extends StatelessWidget {
  const MonthHeader({
    super.key,
    required this.month,
    required this.count,
    this.onTap,
  });

  final YearMonth month;
  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final styles = Theme.of(context).extension<AppTextStyles>()!;
    final colors = Theme.of(context).extension<AppColors>()!;
    final scheme = Theme.of(context).colorScheme;

    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          month.label,
          style: styles.pageTitle.copyWith(
            color: scheme.onSurface,
            fontSize: 18,
          ),
        ),
        const SizedBox(width: AppSpace.s12),
        Expanded(
          child: Text(
            itemCountLabel(count),
            style: styles.caption.copyWith(color: colors.textSecondary),
          ),
        ),
        if (onTap != null)
          Padding(
            padding: const EdgeInsets.only(left: 2),
            child: Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: colors.textMuted,
            ),
          ),
      ],
    );

    if (onTap == null) return row;
    return Semantics(
      button: true,
      child: GestureDetector(
        // The row is mostly whitespace; without this only the label's glyphs
        // would answer a tap.
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: row,
      ),
    );
  }
}
