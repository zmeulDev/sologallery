import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_space.dart';
import '../../../core/theme/app_text_styles.dart';

/// One quiet promise row: a tracked-out uppercase label over a plain-language
/// detail, led by a small hairline dot (the chrome carries no accent color, so
/// contrast and tracking do the work).
class Assurance extends StatelessWidget {
  const Assurance({
    super.key,
    required this.label,
    required this.detail,
    this.color,
  });

  final String label;
  final String detail;
  final AppColors? color;

  @override
  Widget build(BuildContext context) {
    final colors = color ?? Theme.of(context).extension<AppColors>()!;
    final text = Theme.of(context).extension<AppTextStyles>()!;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 5,
            height: 5,
            margin: const EdgeInsets.only(right: 14),
            decoration: BoxDecoration(
              color: colors.textMuted,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: text.sectionLabel.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  detail,
                  style: text.caption.copyWith(color: colors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
