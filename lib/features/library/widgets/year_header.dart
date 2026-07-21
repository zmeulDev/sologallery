import 'package:flutter/material.dart';

import '../../../core/format/count_labels.dart';
import '../../../core/theme/app_space.dart';
import '../../../core/theme/app_text_styles.dart';

/// Announces a year in the grouped timeline: the year set in the display face,
/// with its photo count trailing in the quiet caption voice.
///
/// The whole design system speaks at 11sp uppercase; this is the one place it
/// raises its voice, and the scale jump alone (34sp against the month labels'
/// 11sp) is what establishes the hierarchy — so there is no rule, no chip, and
/// no color behind it. The count earns its place by being information the
/// header would otherwise make the reader go and count for themselves.
class YearHeader extends StatelessWidget {
  const YearHeader({super.key, required this.year, required this.count});

  final int year;
  final int count;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).extension<AppTextStyles>()!;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s16,
        AppSpace.s24,
        AppSpace.s16,
        AppSpace.s4,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text('$year', style: text.display.copyWith(color: scheme.onSurface)),
          const SizedBox(width: AppSpace.s12),
          Expanded(
            child: Text(
              photoCountLabel(count),
              style: text.caption.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
