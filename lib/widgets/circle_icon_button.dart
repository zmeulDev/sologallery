import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// A glyph on a circular disc — the app's round icon affordance.
///
/// Two variants, because the two places one appears have opposite backdrops and
/// a single themed version would be invisible in one of them:
///
/// * [CircleIconButton.overMedia] — a scrim disc with a white glyph, for chrome
///   sitting on a photo (the detail viewer's top bar). Theme-invariant, like
///   every other [AppOverMedia] value: the photo is the background, not the
///   theme.
/// * [CircleIconButton.surface] — a recessed `surface2` disc with an ink glyph,
///   for chrome on the app's own background (the Library app bar).
class CircleIconButton extends StatelessWidget {
  const CircleIconButton.overMedia({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.size = _defaultSize,
  }) : _overMedia = true;

  const CircleIconButton.surface({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.size = _defaultSize,
  }) : _overMedia = false;

  final IconData icon;

  /// Doubles as the accessibility label — every instance is icon-only, so it is
  /// the only name the button has.
  final String tooltip;

  final VoidCallback? onPressed;

  /// Diameter of the disc. The glyph scales with it.
  final double size;

  final bool _overMedia;

  static const double _defaultSize = 40;

  /// Half the disc, which keeps the glyph optically centered in the circle at
  /// any [size] rather than crowding it at the default.
  double get _glyphSize => size / 2;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final scheme = Theme.of(context).colorScheme;
    final background = _overMedia ? AppOverMedia.scrim : colors.surface2;
    final foreground = _overMedia ? AppOverMedia.glyph : scheme.onSurface;

    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: background,
          shape: const CircleBorder(),
          // Clips the ink splash to the disc; without it the ripple paints a
          // square over the photo behind an over-media button.
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: SizedBox.square(
              dimension: size,
              child: Center(
                child: Icon(icon, size: _glyphSize, color: foreground),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
