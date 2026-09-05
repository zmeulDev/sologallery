import 'package:flutter/material.dart';

/// Design-system color tokens that don't map cleanly onto Material's
/// [ColorScheme]. Read via `Theme.of(context).extension<AppColors>()!`.
///
/// The palette is intentionally monochromatic warm-grey: in a photo app the
/// photographs supply all the color, so the chrome stays quiet. Values come
/// straight from docs/design-system.md.
/// Colors drawn *over photos and video* — scrims, glyphs, progress segments.
///
/// Deliberately theme-invariant (media is the background, not the chrome), so
/// this is a const class rather than a [ThemeExtension]: the values never flip
/// with brightness and stay const-constructible in decorations.
abstract final class AppOverMedia {
  /// Standard scrim behind chrome over media (top bar, duration badge).
  static const Color scrim = Color(0x99000000);

  /// Heavier scrim (action bar, card gradient end).
  static const Color scrimHeavy = Color(0xB3000000);

  /// Deepest scrim (memory title-card gradient end).
  static const Color scrimDeep = Color(0xD9000000);

  /// Circular backdrop behind the video play glyph.
  static const Color playScrim = Color(0x66000000);

  /// Primary glyph/text over media.
  static const Color glyph = Colors.white;

  /// Softer glyph/text (white70).
  static const Color glyphSoft = Colors.white70;

  /// Faint glyph/text (white54).
  static const Color glyphFaint = Colors.white54;

  /// Dim structural marks (white24).
  static const Color glyphDim = Colors.white24;

  /// Ghost structural marks (white12).
  static const Color glyphGhost = Colors.white12;

  /// Active progress segment (memory card/player).
  static const Color segment = Color(0x8CFFFFFF);

  /// Inactive progress segment.
  static const Color segmentOff = Color(0x40FFFFFF);
}

/// The palette is intentionally monochromatic warm-grey — in a photo app the
/// photographs supply all the color, so the chrome stays quiet. [accent] is
/// the one deliberate exception, reserved for state and never decoration.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.surface2,
    required this.textSecondary,
    required this.textMuted,
    required this.pillActiveBg,
    required this.pillActiveText,
    required this.border,
    required this.accent,
    required this.accentText,
  });

  /// Recessed surface (e.g. filter track, inactive pill).
  final Color surface2;

  /// Secondary text — captions, supporting labels.
  final Color textSecondary;

  /// Muted text — placeholders, disabled, hairline labels.
  final Color textMuted;

  /// Active pill / selected control background (inverts on dark).
  final Color pillActiveBg;

  /// Text/icon on top of [pillActiveBg].
  final Color pillActiveText;

  /// Hairline border (7% ink).
  final Color border;

  /// The one spot color, scoped strictly to state (an active filter, a
  /// favorited photo, an "on" toggle, the live indexing ring, the memory
  /// player's current segment) — never decoration. Identical value in light
  /// and dark: red reads fine on both a white and a near-black ground.
  final Color accent;

  /// Text-safe variant of [accent] — same red, but chosen so it clears WCAG
  /// AA's 4.5:1 text-contrast threshold against the specific ground each
  /// consumer actually paints it on: `FilterPill`'s selected label sits
  /// directly on the `Scaffold`, so its real ground is
  /// `AppTheme.scaffoldBackgroundColor`, not `scheme.surface`; only
  /// `SegmentedControl`'s selected label (which sits on the control's raised
  /// `scheme.surface` thumb) actually paints on `scheme.surface`. [accent]
  /// itself only clears 3:1 (non-text/UI-component contrast) on some
  /// grounds — use [accentText], never [accent], whenever this red becomes
  /// the colour of *text*.
  final Color accentText;

  static const light = AppColors(
    surface2: Color(0xFFEBEBEB),
    textSecondary: Color(0xFF6E6E6A),
    textMuted: Color(0xFFAEAEA9),
    pillActiveBg: Color(0xFF1A1A18),
    pillActiveText: Color(0xFFF0F0EE),
    border: Color(0x12000000), // rgba(0,0,0,0.07)
    accent: Color(0xFFEB0000),
    // Darker than [accent]: plain #EB0000 only clears 4.5:1 against pure-white
    // scheme.surface (4.633:1), but FilterPill's selected label actually
    // paints on the real light scaffoldBackgroundColor (#F5F5F3), where
    // #EB0000 falls to 4.244:1 and fails AA text contrast. #D80000 clears
    // both real grounds with margin (4.908:1 on #F5F5F3, 5.357:1 on
    // #FFFFFF) — see test/core/theme/app_colors_test.dart.
    accentText: Color(0xFFD80000),
  );

  static const dark = AppColors(
    surface2: Color(0xFF282826),
    textSecondary: Color(0xFF8A8A84),
    textMuted: Color(0xFF4A4A46),
    pillActiveBg: Color(0xFFF0F0EE),
    pillActiveText: Color(0xFF111110),
    border: Color(0x12FFFFFF), // rgba(255,255,255,0.07)
    accent: Color(0xFFEB0000),
    accentText: Color(0xFFFF3B30),
  );

  @override
  AppColors copyWith({
    Color? surface2,
    Color? textSecondary,
    Color? textMuted,
    Color? pillActiveBg,
    Color? pillActiveText,
    Color? border,
    Color? accent,
    Color? accentText,
  }) {
    return AppColors(
      surface2: surface2 ?? this.surface2,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      pillActiveBg: pillActiveBg ?? this.pillActiveBg,
      pillActiveText: pillActiveText ?? this.pillActiveText,
      border: border ?? this.border,
      accent: accent ?? this.accent,
      accentText: accentText ?? this.accentText,
    );
  }

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    return AppColors(
      surface2: Color.lerp(surface2, other.surface2, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      pillActiveBg: Color.lerp(pillActiveBg, other.pillActiveBg, t)!,
      pillActiveText: Color.lerp(pillActiveText, other.pillActiveText, t)!,
      border: Color.lerp(border, other.border, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentText: Color.lerp(accentText, other.accentText, t)!,
    );
  }
}
