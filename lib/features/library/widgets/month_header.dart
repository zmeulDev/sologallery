import 'package:flutter/material.dart';

import '../../../core/theme/app_text_styles.dart';
import '../domain/year_month.dart';
import 'section_count_pill.dart';

/// A sentence-case header for one calendar month in the Library timeline.
///
/// The month name is set at 18 / 700 — smaller than the app-bar page title so
/// year heroes stay the dominant voice, but still heavy enough to read as a
/// section boundary. The count rides in a recessed pill at the trailing end;
/// when [onTap] is set the pill also shows a chevron to hint the whole row opens
/// the full month.
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
    final scheme = Theme.of(context).colorScheme;

    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            month.label,
            style: styles.pageTitle.copyWith(
              color: scheme.onSurface,
              fontSize: 18,
            ),
          ),
        ),
        SectionCountPill(count: count, showChevron: onTap != null),
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
