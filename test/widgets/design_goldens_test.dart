import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:sologallery/core/theme/app_theme.dart';
import 'package:sologallery/widgets/limited_access_banner.dart';
import 'package:sologallery/widgets/month_section_header.dart';

/// Golden coverage for the design-system widgets introduced in Phase 2, in both
/// light and dark themes (see CLAUDE.md Test strategy → Golden tests).
void main() {
  /// One scenario per theme, each on its theme's own background.
  GoldenTestGroup themedGroup(Widget child) {
    return GoldenTestGroup(
      columns: 1,
      children: [
        for (final entry in {'light': AppTheme.light, 'dark': AppTheme.dark}.entries)
          GoldenTestScenario(
            name: entry.key,
            child: Theme(
              data: entry.value,
              child: Material(
                color: entry.value.scaffoldBackgroundColor,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(width: 340, child: child),
                ),
              ),
            ),
          ),
      ],
    );
  }

  goldenTest(
    'MonthSectionHeader renders label and trailing',
    fileName: 'month_section_header',
    builder: () => themedGroup(
      const MonthSectionHeader(
        label: 'July 2026',
        trailing: Text('View all 128'),
      ),
    ),
  );

  goldenTest(
    'LimitedAccessBanner',
    fileName: 'limited_access_banner',
    builder: () => themedGroup(
      LimitedAccessBanner(onSelectMore: () {}),
    ),
  );
}
