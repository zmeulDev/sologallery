import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/core/theme/app_colors.dart';

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
    test('clears 4.5:1 against scheme.surface in both themes', () {
      // Light scheme.surface is pure white; dark is #1C1C1A — see
      // app_theme.dart:22,30. FilterPill and SegmentedControl (Phase 1)
      // both paint accentText as text directly on scheme.surface.
      expect(
        _contrastRatio(AppColors.light.accentText, const Color(0xFFFFFFFF)),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(AppColors.dark.accentText, const Color(0xFF1C1C1A)),
        greaterThanOrEqualTo(4.5),
      );
    });
  });
}
