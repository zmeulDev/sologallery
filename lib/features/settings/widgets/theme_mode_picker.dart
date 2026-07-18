import 'package:flutter/material.dart';

import '../../../widgets/filter_pill.dart';

/// The Appearance theme control: a three-way segmented pill row (System / Light
/// / Dark) built from the design-system [FilterPill], so it reads as the same
/// facet control used in Search. Stateless — the selection and persistence live
/// in the Settings screen / [SettingsDao].
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
    return Row(
      children: [
        for (final option in ThemeMode.values) ...[
          FilterPill(
            label: _label(option),
            selected: option == mode,
            onTap: () => onChanged(option),
          ),
          if (option != ThemeMode.values.last) const SizedBox(width: 8),
        ],
      ],
    );
  }
}
