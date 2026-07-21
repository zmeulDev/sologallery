import 'package:flutter/material.dart';

import '../../../widgets/segmented_control.dart';

/// The Appearance theme control: System / Light / Dark as a full-width
/// [SegmentedControl].
///
/// A segmented control rather than the pill row used in Search, because these
/// three are one value with three mutually exclusive settings — not three
/// independent facets that happen to sit in a row. Stateless; the selection and
/// its persistence live in the Settings screen / `SettingsDao`.
class ThemeModePicker extends StatelessWidget {
  const ThemeModePicker({
    super.key,
    required this.mode,
    required this.onChanged,
  });

  final ThemeMode mode;
  final ValueChanged<ThemeMode> onChanged;

  static String _label(ThemeMode mode) => switch (mode) {
    ThemeMode.system => 'System',
    ThemeMode.light => 'Light',
    ThemeMode.dark => 'Dark',
  };

  @override
  Widget build(BuildContext context) {
    return SegmentedControl<ThemeMode>(
      options: ThemeMode.values,
      value: mode,
      labelBuilder: _label,
      onChanged: onChanged,
    );
  }
}
