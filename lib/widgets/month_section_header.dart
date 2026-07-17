import 'package:flutter/material.dart';

import '../core/theme/app_text_styles.dart';

/// Header row for a Library month section: a tracked-out uppercase month label
/// (the typographic signature of the design system) with an optional trailing
/// affordance such as the "View all" control.
class MonthSectionHeader extends StatelessWidget {
  const MonthSectionHeader({
    super.key,
    required this.label,
    this.trailing,
  });

  /// The month, e.g. `July 2026`. Rendered uppercase by the section-label style.
  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).extension<AppTextStyles>()!;
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            label.toUpperCase(),
            style: text.sectionLabel.copyWith(color: scheme.onSurface),
          ),
        ),
        ?trailing,
      ],
    );
  }
}
