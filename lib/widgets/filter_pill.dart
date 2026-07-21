import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_motion.dart';
import '../core/theme/app_text_styles.dart';

/// A selectable filter pill — the design system's segment/facet control. Active
/// inverts to the ink fill (`pillActiveBg`); inactive is a quiet recessed
/// surface with a hairline border. Used by the Search facets (media type,
/// favorites) and available to any future filter row.
///
/// Selection eases between the two states (fill, hairline, label color) on the
/// short motion token. One [TweenAnimationBuilder] drives all three lerps so
/// they share a single curve; [Material] stays the painter, which keeps the end
/// states pixel-identical to the pre-animation pill (an [AnimatedContainer]
/// with a [ShapeDecoration] strokes the hairline without Material's shape
/// clip and drifts by a few antialiasing counts on the curved caps — the
/// `filter_pill` / `theme_mode_picker` goldens pin this). The selected side is
/// a transparent width-1 stroke rather than [BorderSide.none] so the lerp
/// never pops between border styles; under the stadium clip it paints nothing.
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
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: selected ? 1 : 0),
      duration: AppMotion.of(context, AppMotion.short),
      curve: AppMotion.curve,
      builder: (context, t, _) {
        return Material(
          color: Color.lerp(colors.surface2, colors.pillActiveBg, t),
          shape: StadiumBorder(
            side: BorderSide(
              color: Color.lerp(colors.border, colors.border.withAlpha(0), t)!,
            ),
          ),
          // The per-frame lerped values must apply as-is; Material's own
          // implicit shape/color animation would chase them 200ms behind.
          animationDuration: Duration.zero,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              child: Text(
                label,
                style: styles.filterPill.copyWith(
                  color: Color.lerp(
                    colors.textSecondary,
                    colors.pillActiveText,
                    t,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
