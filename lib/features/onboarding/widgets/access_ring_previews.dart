import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

import '../../../core/theme/app_theme.dart';
import 'access_ring.dart';

/// Isolated previews for [AccessRing] — the onboarding poster's decorative
/// ring, built and eyeballed here before Task 1 wires it into `AccessStep`.
///
/// Run with `flutter widget-preview start`. Real [AppTheme.light]/[.dark] are
/// used (not stand-in colors) so the previewer's rendering of the ring's
/// stroke actually exercises `AppColors.accent`.

/// Theming shared by every preview below.
PreviewThemeData accessRingPreviewTheme() =>
    PreviewThemeData(materialLight: AppTheme.light, materialDark: AppTheme.dark);

/// [AccessRing] at a small diameter, in both themes.
@Preview(
  name: 'AccessRing — small (240), light',
  theme: accessRingPreviewTheme,
  brightness: Brightness.light,
)
@Preview(
  name: 'AccessRing — small (240), dark',
  theme: accessRingPreviewTheme,
  brightness: Brightness.dark,
)
Widget accessRingSmallPreview() => const Center(child: AccessRing(diameter: 240));

/// [AccessRing] at a large diameter, in both themes — stands in for
/// `AccessStep`'s eventual "fraction of screen width" sizing (Task 1).
@Preview(
  name: 'AccessRing — large (420), light',
  theme: accessRingPreviewTheme,
  brightness: Brightness.light,
)
@Preview(
  name: 'AccessRing — large (420), dark',
  theme: accessRingPreviewTheme,
  brightness: Brightness.dark,
)
Widget accessRingLargePreview() => const Center(child: AccessRing(diameter: 420));
