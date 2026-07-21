import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';

/// The tracked-out uppercase label that opens a section — the typographic
/// signature of the design system. Leads Library months, Memories, People,
/// Albums, Device folders and the Search result groups.
///
/// With [onTap] the whole row becomes the target for the section's destination
/// (a Library month opening its full grid) and grows a trailing chevron, so the
/// affordance is the header itself rather than a separate button competing with
/// it for the same job.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.label,
    this.trailing,
    this.onTap,
  });

  /// The section name, e.g. `July 2026`. Rendered uppercase by the section-label
  /// style — pass it in natural case.
  final String label;

  /// Optional quiet affordance at the end of the row, such as a count. Sits
  /// before the chevron when [onTap] is also set.
  final Widget? trailing;

  /// Makes the entire row tappable and appends a chevron.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final styles = Theme.of(context).extension<AppTextStyles>()!;
    final colors = Theme.of(context).extension<AppColors>()!;
    final scheme = Theme.of(context).colorScheme;

    final row = Row(
      children: [
        Expanded(
          child: Text(
            label.toUpperCase(),
            style: styles.sectionLabel.copyWith(color: scheme.onSurface),
          ),
        ),
        ?trailing,
        if (onTap != null)
          Padding(
            padding: const EdgeInsets.only(left: 2),
            child: Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: colors.textMuted,
            ),
          ),
      ],
    );

    if (onTap == null) return row;
    return Semantics(
      button: true,
      child: GestureDetector(
        // The row is mostly whitespace; without this only the label's glyphs
        // would answer a tap.
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: row,
      ),
    );
  }
}
