import 'package:flutter/material.dart';

import '../../../core/theme/app_space.dart';
import '../../../core/theme/app_text_styles.dart';
import 'section_count_pill.dart';

/// Announces a year in the grouped timeline: the year set in the display face,
/// with the photo count in a quiet pill at the trailing end.
///
/// When [onTap] is provided the whole row becomes tappable and the pill shows a
/// chevron, so the year hero opens its full grid the same way a month section
/// header does.
class YearHeader extends StatelessWidget {
  const YearHeader({
    super.key,
    required this.year,
    required this.count,
    this.onTap,
  });

  final int year;
  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).extension<AppTextStyles>()!;
    final scheme = Theme.of(context).colorScheme;
    final row = Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s16,
        AppSpace.s24,
        AppSpace.s16,
        AppSpace.s4,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text('$year', style: text.display.copyWith(color: scheme.onSurface)),
          const SizedBox(width: AppSpace.s12),
          const Spacer(),
          SectionCountPill(count: count, showChevron: onTap != null),
        ],
      ),
    );

    if (onTap == null) return row;
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: row,
      ),
    );
  }
}
