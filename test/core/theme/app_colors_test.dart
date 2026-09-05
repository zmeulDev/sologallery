import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/core/theme/app_theme.dart';

double _contrastRatio(Color a, Color b) {
  final lA = a.computeLuminance();
  final lB = b.computeLuminance();
  final lighter = lA > lB ? lA : lB;
  final darker = lA > lB ? lB : lA;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  group('AppColors.accent', () {
    test('light and dark both define the same spot colour', () {
      const expected = Color(0xFFEB0000);
      expect(AppColors.light.accent, expected);
      expect(AppColors.dark.accent, expected);
    });
  });

  group('AppColors.accentText', () {
    // accentText is painted as *text* by two different consumers on two
    // different real grounds, not the single `scheme.surface` this test used
    // to assume:
    //  - FilterPill's selected label is a bare Scaffold child with no
    //    backgroundColor override, so its real ground is
    //    AppTheme.scaffoldBackgroundColor.
    //  - SegmentedControl's selected label sits on the control's raised
    //    thumb, which is filled with scheme.surface.
    // Reading both grounds straight off the built ThemeData (rather than
    // hardcoding their hex literals here) keeps this test honest if either
    // ground ever moves.
    test('clears 4.5:1 against the real FilterPill ground '
        '(scaffoldBackgroundColor) in both themes', () {
      expect(
        _contrastRatio(
          AppColors.light.accentText,
          AppTheme.light.scaffoldBackgroundColor,
        ),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(
          AppColors.dark.accentText,
          AppTheme.dark.scaffoldBackgroundColor,
        ),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('clears 4.5:1 against the real SegmentedControl thumb ground '
        '(scheme.surface) in both themes', () {
      expect(
        _contrastRatio(
          AppColors.light.accentText,
          AppTheme.light.colorScheme.surface,
        ),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(
          AppColors.dark.accentText,
          AppTheme.dark.colorScheme.surface,
        ),
        greaterThanOrEqualTo(4.5),
      );
    });
  });
}
