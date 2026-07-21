import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_space.dart';
import '../core/theme/app_text_styles.dart';

/// Shown at the top of the Library when access is limited (the user shared only
/// some photos). Explains the state plainly and offers a way to widen the
/// selection. Purely presentational — the caller wires [onSelectMore].
class LimitedAccessBanner extends StatelessWidget {
  const LimitedAccessBanner({super.key, required this.onSelectMore});

  final VoidCallback onSelectMore;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final text = Theme.of(context).extension<AppTextStyles>()!;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpace.s16,
        AppSpace.s8,
        AppSpace.s16,
        AppSpace.s4,
      ),
      padding: const EdgeInsets.fromLTRB(14, AppSpace.s12, AppSpace.s8, AppSpace.s12),
      decoration: BoxDecoration(
        color: colors.surface2,
        borderRadius: AppRadius.br12,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'You\'re showing selected photos only.',
              style: text.body.copyWith(color: scheme.onSurface),
            ),
          ),
          TextButton(
            onPressed: onSelectMore,
            style: TextButton.styleFrom(
              foregroundColor: scheme.onSurface,
              textStyle: text.filterPill.copyWith(fontWeight: FontWeight.w600),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.s12,
                vertical: 6,
              ),
            ),
            child: const Text('Select more'),
          ),
        ],
      ),
    );
  }
}
