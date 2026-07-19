import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// The one switch style the app uses, in onboarding and Settings alike. Its
/// active track is [AppColors.pillActiveBg] — the design system's single
/// high-contrast token — so consent introduces no new accent color.
class ConsentSwitch extends StatelessWidget {
  const ConsentSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    required this.semanticLabel,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  /// Read out by screen readers in place of the visual label beside it.
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    return Semantics(
      label: semanticLabel,
      child: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: colors.pillActiveText,
        activeTrackColor: colors.pillActiveBg,
        inactiveThumbColor: Theme.of(context).colorScheme.surface,
        inactiveTrackColor: colors.surface2,
        trackOutlineColor: WidgetStatePropertyAll(colors.border),
      ),
    );
  }
}
