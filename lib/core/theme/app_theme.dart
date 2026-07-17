import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';

export 'app_colors.dart';
export 'app_text_styles.dart';

/// Light and dark [ThemeData] for SoloGallery, built from the CLAUDE.md
/// "Design system" tokens. The palette is monochromatic warm-grey with no
/// accent — photos carry the color, chrome stays neutral.
abstract final class AppTheme {
  static ThemeData get light => _build(
        brightness: Brightness.light,
        colors: AppColors.light,
        background: const Color(0xFFF5F5F3),
        surface: const Color(0xFFFFFFFF),
        textPrimary: const Color(0xFF111110),
      );

  static ThemeData get dark => _build(
        brightness: Brightness.dark,
        colors: AppColors.dark,
        background: const Color(0xFF111110),
        surface: const Color(0xFF1C1C1A),
        textPrimary: const Color(0xFFF0F0EE),
      );

  static ThemeData _build({
    required Brightness brightness,
    required AppColors colors,
    required Color background,
    required Color surface,
    required Color textPrimary,
  }) {
    final colorScheme = ColorScheme(
      brightness: brightness,
      // "primary" is the inverted near-black/near-white used by active
      // controls (pills, selected states).
      primary: colors.pillActiveBg,
      onPrimary: colors.pillActiveText,
      secondary: colors.pillActiveBg,
      onSecondary: colors.pillActiveText,
      surface: surface,
      onSurface: textPrimary,
      surfaceContainerHighest: colors.surface2,
      outline: colors.border,
      error: const Color(0xFFB3261E),
      onError: const Color(0xFFFFFFFF),
    );

    final textTheme = _textTheme(textPrimary, colors.textSecondary);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      textTheme: textTheme,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppTextStyles.standard.pageTitle.copyWith(
          color: textPrimary,
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),
      iconTheme: IconThemeData(color: textPrimary),
      dividerTheme: DividerThemeData(
        color: colors.border,
        thickness: 1,
        space: 1,
      ),
      extensions: [colors, AppTextStyles.standard],
    );
  }

  /// Maps the design type scale onto Material's [TextTheme] slots so stock
  /// widgets pick up the right sizes. Semantic roles live in [AppTextStyles].
  static TextTheme _textTheme(Color primary, Color secondary) {
    const s = AppTextStyles.standard;
    return TextTheme(
      titleLarge: s.pageTitle.copyWith(color: primary),
      titleMedium: s.body.copyWith(fontWeight: FontWeight.w600, color: primary),
      bodyLarge: s.body.copyWith(color: primary),
      bodyMedium: s.body.copyWith(color: primary),
      bodySmall: s.caption.copyWith(color: secondary),
      labelLarge: s.filterPill.copyWith(color: primary),
      labelSmall: s.sectionLabel.copyWith(color: secondary),
    );
  }
}
