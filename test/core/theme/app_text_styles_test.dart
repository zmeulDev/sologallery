import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/core/theme/app_text_styles.dart';

void main() {
  group('AppTextStyles.standard weights', () {
    test('every role resolves to w400 or w700, never a third weight', () {
      const styles = AppTextStyles.standard;
      final allowed = [FontWeight.w400, FontWeight.w700];
      final roles = <String, TextStyle>{
        'display': styles.display,
        'pageTitle': styles.pageTitle,
        'sectionLabel': styles.sectionLabel,
        'filterPill': styles.filterPill,
        'body': styles.body,
        'button': styles.button,
        'exifValue': styles.exifValue,
        'exifKey': styles.exifKey,
        'caption': styles.caption,
      };

      for (final entry in roles.entries) {
        expect(
          entry.value.fontWeight,
          anyOf(allowed),
          reason:
              '${entry.key} must resolve to w400 or w700, a shared role '
              'must never reintroduce w500/w600',
        );
      }
    });
  });
}
