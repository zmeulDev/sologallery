import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// The one switch style the app uses, in onboarding and Settings alike. Its
/// active track is [AppColors.accent] — the red state color for the on
/// toggle.
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
        // Hardcoded, not a theme token: the track is now theme-invariant
        // accent red, so the thumb on it should be too, rather than
        // reintroducing a theme-dependent swap against a theme-independent
        // ground (same call as NavPillBar's knob glyph).
        activeThumbColor: Colors.white,
        activeTrackColor: colors.accent,
        inactiveThumbColor: Theme.of(context).colorScheme.surface,
        inactiveTrackColor: colors.surface2,
        trackOutlineColor: WidgetStatePropertyAll(colors.border),
      ),
    );
  }
}
