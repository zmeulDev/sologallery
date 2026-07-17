import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// A quiet centered empty-state for screens that aren't built yet. Uses the
/// muted text token so it reads as scaffolding, not content.
class PlaceholderView extends StatelessWidget {
  const PlaceholderView({
    super.key,
    required this.icon,
    required this.message,
  });

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final styles = Theme.of(context).extension<AppTextStyles>()!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: colors.textMuted),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: styles.body.copyWith(color: colors.textMuted),
          ),
        ],
      ),
    );
  }
}
