import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/core/theme/app_colors.dart';

void main() {
  group('AppColors.accent', () {
    test('light and dark both define the same spot colour', () {
      const expected = Color(0xFFEB0000);
      expect(AppColors.light.accent, expected);
      expect(AppColors.dark.accent, expected);
    });
  });
}
