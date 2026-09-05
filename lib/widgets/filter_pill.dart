import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';

/// A selectable filter pill — the design system's segment/facet control.
/// Active shows a transparent fill with an accent border and label — the ink
/// fill is gone; state now reads through colour, not inversion. Inactive is a
/// quiet recessed surface with a hairline border. Used by the Search facets
/// (media type, favorites) and available to any future filter row.
///
/// Selection is an instant state change — the fill, border and label color
/// all swap on the tap. [Material] stays the painter, which keeps the end
/// states pixel-identical to the original pill (an [AnimatedContainer] with a
/// [ShapeDecoration] strokes the hairline without Material's shape clip and
/// drifts by a few antialiasing counts on the curved caps — the `filter_pill` /
/// `theme_mode_picker` goldens pin this).
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
      color: selected ? Colors.transparent : colors.surface2,
      shape: StadiumBorder(
        side: BorderSide(color: selected ? colors.accent : colors.border),
      ),
      // The colours are direct conditionals; Material's own implicit
      // shape/color animation would chase the swap, so it must be instant.
      animationDuration: Duration.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          child: Text(
            label,
            style: styles.filterPill.copyWith(
              color: selected ? colors.accentText : colors.textSecondary,
              fontWeight: selected ? FontWeight.w700 : null,
            ),
          ),
        ),
      ),
    );
  }
}
