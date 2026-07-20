import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';

enum _AppButtonVariant { primary, secondary, quiet }

/// The design system's one button widget, in three voices.
///
/// Built on [Material] + [InkWell] rather than the Material button classes so
/// height, shape, and typography come straight from the design tokens instead
/// of M3 defaults. Every shape is a [StadiumBorder] — the inverted-ink pill is
/// the app's action motif.
class AppButton extends StatelessWidget {
  /// The high-contrast pill CTA (inverted ink): 52 high, `pillActiveBg` fill.
  /// [busy] swaps the label for a small spinner (the tap is expected to be
  /// disabled by passing a null [onPressed] while busy). [expand] stretches
  /// the pill to the available width (the onboarding treatment).
  const AppButton.primary({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.expand = false,
  })  : _variant = _AppButtonVariant.primary,
        icon = null,
        chevron = false;

  /// The quiet-surface action: 40 high, `surface2` fill with a hairline side,
  /// optional 18px leading [icon]. For secondary CTAs (e.g. "New album").
  const AppButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  })  : _variant = _AppButtonVariant.secondary,
        busy = false,
        expand = false,
        chevron = false;

  /// The unfilled inline affordance ("View all N", "See all"): `filterPill`
  /// label in `textSecondary`, optional trailing [chevron], compact tap target.
  const AppButton.quiet({
    super.key,
    required this.label,
    required this.onPressed,
    this.chevron = false,
  })  : _variant = _AppButtonVariant.quiet,
        busy = false,
        expand = false,
        icon = null;

  final String label;
  final VoidCallback? onPressed;

  /// Primary only: show the busy spinner instead of the label.
  final bool busy;

  /// Primary only: fill the available width.
  final bool expand;

  /// Secondary only: optional leading icon.
  final IconData? icon;

  /// Quiet only: trailing chevron.
  final bool chevron;

  final _AppButtonVariant _variant;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final styles = Theme.of(context).extension<AppTextStyles>()!;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return switch (_variant) {
      _AppButtonVariant.primary => SizedBox(
          width: expand ? double.infinity : null,
          height: 52,
          child: Material(
            color: colors.pillActiveBg,
            shape: const StadiumBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onPressed,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Center(
                  widthFactor: 1,
                  child: busy
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colors.pillActiveText,
                          ),
                        )
                      : Text(
                          label,
                          style: styles.button
                              .copyWith(color: colors.pillActiveText),
                        ),
                ),
              ),
            ),
          ),
        ),
      _AppButtonVariant.secondary => SizedBox(
          height: 40,
          child: Material(
            color: colors.surface2,
            shape: StadiumBorder(side: BorderSide(color: colors.border)),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onPressed,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon case final leading?) ...[
                      Icon(leading, size: 18, color: onSurface),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      label,
                      style: styles.button
                          .copyWith(fontSize: 14, color: onSurface),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      _AppButtonVariant.quiet => Material(
          type: MaterialType.transparency,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: SizedBox(
                height: 36,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: styles.filterPill
                          .copyWith(color: colors.textSecondary),
                    ),
                    if (chevron) ...[
                      const SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: colors.textSecondary,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
    };
  }
}
