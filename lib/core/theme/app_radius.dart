import 'package:flutter/widgets.dart';

/// Corner-radius scale. Pills use [StadiumBorder] and need no token here.
abstract final class AppRadius {
  /// Grab handles, progress segments.
  static const double r2 = 2;

  /// Duration badge.
  static const double r4 = 4;

  /// Buttons, chips, cards, banners, filled input fields.
  static const double r8 = 8;

  /// Cards, banners, filled input fields, and every photo thumbnail — grid
  /// cells, previews and row covers all clip to this one radius.
  static const double r12 = 12;

  /// Floating surfaces: bottom sheets and dialogs share one corner.
  static const double r20 = 20;

  static const BorderRadius br4 = BorderRadius.all(Radius.circular(r4));
  static const BorderRadius br8 = BorderRadius.all(Radius.circular(r8));
  static const BorderRadius br12 = BorderRadius.all(Radius.circular(r12));
  static const BorderRadius br20 = BorderRadius.all(Radius.circular(r20));
}
