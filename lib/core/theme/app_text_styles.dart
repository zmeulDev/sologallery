import 'package:flutter/material.dart';

/// The named typographic roles from CLAUDE.md "Design system". These are
/// semantic (page title, EXIF key, …) rather than Material's size-named slots,
/// so widgets ask for meaning, not size. Read via
/// `Theme.of(context).extension<AppTextStyles>()!`.
///
/// Colors are left null here; each style inherits the ambient text color
/// unless a widget sets one explicitly.
@immutable
class AppTextStyles extends ThemeExtension<AppTextStyles> {
  const AppTextStyles({
    required this.pageTitle,
    required this.sectionLabel,
    required this.filterPill,
    required this.body,
    required this.exifValue,
    required this.exifKey,
    required this.caption,
  });

  /// Screen title in the app bar. 22 / 700.
  final TextStyle pageTitle;

  /// Uppercase group header. 11 / 600, tracked out (the typographic signature).
  final TextStyle sectionLabel;

  /// Filter/segment pill label. 12 / 500.
  final TextStyle filterPill;

  /// Default body & list text. 14 / 400.
  final TextStyle body;

  /// EXIF metadata value. 12 / 600.
  final TextStyle exifValue;

  /// EXIF metadata key (uppercase). 9 / 400.
  final TextStyle exifKey;

  /// Small supporting caption. 11 / 400.
  final TextStyle caption;

  static const AppTextStyles standard = AppTextStyles(
    pageTitle: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, height: 1.1),
    sectionLabel: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.88, // ~0.08em at 11sp
      height: 1.2,
    ),
    filterPill: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
    body: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, height: 1.4),
    exifValue: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
    exifKey: TextStyle(
      fontSize: 9,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.72, // ~0.08em at 9sp
    ),
    caption: TextStyle(fontSize: 11, fontWeight: FontWeight.w400),
  );

  @override
  AppTextStyles copyWith({
    TextStyle? pageTitle,
    TextStyle? sectionLabel,
    TextStyle? filterPill,
    TextStyle? body,
    TextStyle? exifValue,
    TextStyle? exifKey,
    TextStyle? caption,
  }) {
    return AppTextStyles(
      pageTitle: pageTitle ?? this.pageTitle,
      sectionLabel: sectionLabel ?? this.sectionLabel,
      filterPill: filterPill ?? this.filterPill,
      body: body ?? this.body,
      exifValue: exifValue ?? this.exifValue,
      exifKey: exifKey ?? this.exifKey,
      caption: caption ?? this.caption,
    );
  }

  @override
  AppTextStyles lerp(AppTextStyles? other, double t) {
    if (other == null) return this;
    return AppTextStyles(
      pageTitle: TextStyle.lerp(pageTitle, other.pageTitle, t)!,
      sectionLabel: TextStyle.lerp(sectionLabel, other.sectionLabel, t)!,
      filterPill: TextStyle.lerp(filterPill, other.filterPill, t)!,
      body: TextStyle.lerp(body, other.body, t)!,
      exifValue: TextStyle.lerp(exifValue, other.exifValue, t)!,
      exifKey: TextStyle.lerp(exifKey, other.exifKey, t)!,
      caption: TextStyle.lerp(caption, other.caption, t)!,
    );
  }
}
