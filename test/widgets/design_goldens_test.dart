import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sologallery/core/database/daos/albums_dao.dart' show AlbumSummary;
import 'package:sologallery/core/theme/app_theme.dart';
import 'package:sologallery/features/albums/widgets/album_card.dart';
import 'package:sologallery/features/settings/widgets/theme_mode_picker.dart';
import 'package:sologallery/services/permission_provider.dart';
import 'package:sologallery/widgets/asset_thumbnail.dart';
import 'package:sologallery/widgets/filter_pill.dart';
import 'package:sologallery/widgets/limited_access_banner.dart';
import 'package:sologallery/widgets/month_section_header.dart';

import '../support/fake_photo_library_service.dart';

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

  // The badge carries its own contrast (it sits over a photo), so it reads the
  // same in both themes; the group still renders light + dark for consistency.
  goldenTest(
    'DurationBadge — short and long clips',
    fileName: 'duration_badge',
    builder: () => themedGroup(
      const Row(
        children: [
          DurationBadge(duration: Duration(seconds: 42)),
          SizedBox(width: 12),
          DurationBadge(duration: Duration(minutes: 1, seconds: 5)),
          SizedBox(width: 12),
          DurationBadge(duration: Duration(hours: 1, minutes: 2, seconds: 3)),
        ],
      ),
    ),
  );

  goldenTest(
    'FilterPill — selected and unselected',
    fileName: 'filter_pill',
    builder: () => themedGroup(
      Row(
        children: [
          FilterPill(label: 'All', selected: true, onTap: () {}),
          const SizedBox(width: 8),
          FilterPill(label: 'Videos', selected: false, onTap: () {}),
        ],
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

  goldenTest(
    'ThemeModePicker — system selected',
    fileName: 'theme_mode_picker',
    builder: () => themedGroup(
      ThemeModePicker(mode: ThemeMode.system, onChanged: (_) {}),
    ),
  );

  // The fake returns null thumbnail bytes, so covers render as the deterministic
  // recessed placeholder — the card chrome (name + count) is what's under test.
  goldenTest(
    'AlbumCard — populated and empty',
    fileName: 'album_card',
    builder: () => themedGroup(
      ProviderScope(
        overrides: [
          photoLibraryServiceProvider
              .overrideWithValue(FakePhotoLibraryService()),
        ],
        child: const Row(
          children: [
            SizedBox(
              width: 150,
              height: 190,
              child: AlbumCard(
                summary: AlbumSummary(
                  id: 1,
                  name: 'Iceland 2026',
                  entryCount: 128,
                  coverAssetId: 'x',
                ),
              ),
            ),
            SizedBox(width: 16),
            SizedBox(
              width: 150,
              height: 190,
              child: AlbumCard(
                summary: AlbumSummary(
                  id: 2,
                  name: 'Empty',
                  entryCount: 0,
                  coverAssetId: null,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
