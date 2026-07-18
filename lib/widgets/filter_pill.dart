import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';

/// A selectable filter pill — the design system's segment/facet control. Active
/// inverts to the ink fill (`pillActiveBg`); inactive is a quiet recessed
/// surface with a hairline border. Used by the Search facets (media type,
/// favorites) and available to any future filter row.
class FilterPill extends StatelessWidget {
  const FilterPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final styles = Theme.of(context).extension<AppTextStyles>()!;
    return Material(
      color: selected ? colors.pillActiveBg : colors.surface2,
      shape: StadiumBorder(
        side: selected
            ? BorderSide.none
            : BorderSide(color: colors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          child: Text(
            label,
            style: styles.filterPill.copyWith(
              color: selected ? colors.pillActiveText : colors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
