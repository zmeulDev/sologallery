/// Spacing scale for paddings, gaps, and section rhythm.
///
/// A plain const class rather than a [ThemeExtension]: spacing is
/// theme-invariant, and consts keep `const EdgeInsets.all(AppSpace.s16)`
/// const-constructible.
abstract final class AppSpace {
  /// Photo-grid gutter (edge-to-edge thumbnail grids).
  static const double s2 = 2;

  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;

  /// Standard horizontal screen inset.
  static const double s16 = 16;

  static const double s20 = 20;
  static const double s24 = 24;
  static const double s32 = 32;
}
