import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_motion.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_text_styles.dart';

/// A full-width segmented control: equal-width options in a recessed track, with
/// a raised thumb that slides to the selected one.
///
/// Distinct from [FilterPill], deliberately. A pill row is a *set* of
/// independent facets that happen to be laid out together — each one can be on
/// or off, and the row can scroll. A segmented control is a single value with
/// mutually exclusive choices, so it fills its width, splits it evenly, and
/// animates one thumb between positions instead of restyling each segment. Used
/// by Appearance (System / Light / Dark).
class SegmentedControl<T> extends StatelessWidget {
  const SegmentedControl({
    super.key,
    required this.options,
    required this.value,
    required this.labelBuilder,
    required this.onChanged,
  });

  /// The choices, in display order. Must be non-empty.
  final List<T> options;

  /// The current selection. A value absent from [options] simply shows no
  /// thumb, rather than asserting — a transient mismatch mid-load should not
  /// crash a settings screen.
  final T value;

  final String Function(T) labelBuilder;
  final ValueChanged<T> onChanged;

  /// Gap between the track edge and the thumb.
  static const double _inset = 3;

  static const double _height = 38;

  /// The thumb's corner, tucked inside the track's [AppRadius.r12] by [_inset]
  /// so the two curves stay concentric instead of the thumb reading square.
  static final BorderRadius _thumbRadius = BorderRadius.circular(
    AppRadius.r12 - _inset,
  );

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final styles = Theme.of(context).extension<AppTextStyles>()!;
    final scheme = Theme.of(context).colorScheme;
    final selectedIndex = options.indexOf(value);

    return Container(
      decoration: BoxDecoration(
        color: colors.surface2,
        borderRadius: AppRadius.br12,
      ),
      padding: const EdgeInsets.all(_inset),
      child: SizedBox(
        height: _height,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final segmentWidth = constraints.maxWidth / options.length;
            return Stack(
              children: [
                if (selectedIndex >= 0)
                  AnimatedPositioned(
                    duration: AppMotion.of(context, AppMotion.short),
                    curve: AppMotion.curve,
                    left: segmentWidth * selectedIndex,
                    top: 0,
                    bottom: 0,
                    width: segmentWidth,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: scheme.surface,
                        borderRadius: _thumbRadius,
                        border: Border.all(color: colors.border),
                      ),
                    ),
                  ),
                Row(
                  children: [
                    for (final (index, option) in options.indexed)
                      Expanded(
                        child: Semantics(
                          button: true,
                          selected: index == selectedIndex,
                          child: GestureDetector(
                            // Opaque so a tap anywhere in the segment counts,
                            // not just on the label's glyphs.
                            behavior: HitTestBehavior.opaque,
                            onTap: () => onChanged(option),
                            child: Center(
                              child: AnimatedDefaultTextStyle(
                                duration: AppMotion.of(
                                  context,
                                  AppMotion.short,
                                ),
                                curve: AppMotion.curve,
                                style: styles.button.copyWith(
                                  color: index == selectedIndex
                                      ? scheme.onSurface
                                      : colors.textSecondary,
                                ),
                                child: Text(labelBuilder(option)),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
