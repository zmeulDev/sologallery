import 'package:flutter/material.dart';

/// Design-system color tokens that don't map cleanly onto Material's
/// [ColorScheme]. Read via `Theme.of(context).extension<AppColors>()!`.
///
/// The palette is intentionally monochromatic warm-grey with no accent color:
/// in a photo app the photographs supply all the color, so the chrome stays
/// quiet. Values come straight from CLAUDE.md "Design system".
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.surface2,
    required this.textSecondary,
    required this.textMuted,
    required this.pillActiveBg,
    required this.pillActiveText,
    required this.border,
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

  static const light = AppColors(
    surface2: Color(0xFFEBEBEB),
    textSecondary: Color(0xFF6E6E6A),
    textMuted: Color(0xFFAEAEA9),
    pillActiveBg: Color(0xFF1A1A18),
    pillActiveText: Color(0xFFF0F0EE),
    border: Color(0x12000000), // rgba(0,0,0,0.07)
  );

  static const dark = AppColors(
    surface2: Color(0xFF282826),
    textSecondary: Color(0xFF8A8A84),
    textMuted: Color(0xFF4A4A46),
    pillActiveBg: Color(0xFFF0F0EE),
    pillActiveText: Color(0xFF111110),
    border: Color(0x12FFFFFF), // rgba(255,255,255,0.07)
  );

  @override
  AppColors copyWith({
    Color? surface2,
    Color? textSecondary,
    Color? textMuted,
    Color? pillActiveBg,
    Color? pillActiveText,
    Color? border,
  }) {
    return AppColors(
      surface2: surface2 ?? this.surface2,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      pillActiveBg: pillActiveBg ?? this.pillActiveBg,
      pillActiveText: pillActiveText ?? this.pillActiveText,
      border: border ?? this.border,
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
    );
  }
}
