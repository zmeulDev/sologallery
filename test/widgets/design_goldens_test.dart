import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sologallery/core/database/daos/albums_dao.dart'
    show AlbumSummary;
import 'package:sologallery/core/theme/app_theme.dart';
import 'package:sologallery/core/database/daos/memories_dao.dart'
    show MemorySummary;
import 'package:sologallery/features/albums/widgets/album_card.dart';
import 'package:sologallery/core/database/daos/faces_dao.dart'
    show PersonSummary;
import 'package:sologallery/features/library/widgets/year_header.dart';
import 'package:sologallery/features/people/people_providers.dart';
import 'package:sologallery/features/memories/widgets/memory_card.dart';
import 'package:sologallery/features/settings/widgets/theme_mode_picker.dart';
import 'package:sologallery/services/indexing_service.dart';
import 'package:sologallery/services/permission_provider.dart';
import 'package:sologallery/widgets/indexing_banner.dart';
import 'package:sologallery/widgets/app_button.dart';
import 'package:sologallery/widgets/app_card.dart';
import 'package:sologallery/widgets/app_sheet.dart';
import 'package:sologallery/widgets/asset_thumbnail.dart';
import 'package:sologallery/widgets/circle_icon_button.dart';
import 'package:sologallery/widgets/consent_switch.dart';
import 'package:sologallery/widgets/cover_row.dart';
import 'package:sologallery/widgets/nav_pill_bar.dart';
import 'package:sologallery/widgets/people_strip.dart';
import 'package:sologallery/widgets/empty_state.dart';
import 'package:sologallery/widgets/filter_pill.dart';
import 'package:sologallery/widgets/limited_access_banner.dart';
import 'package:sologallery/widgets/section_header.dart';
import 'package:sologallery/widgets/segmented_control.dart';

import '../support/fake_photo_library_service.dart';

/// Golden coverage for the design-system widgets introduced in Phase 2, in both
/// light and dark themes (see CLAUDE.md Test strategy → Golden tests).
void main() {
  /// One scenario per theme, each on its theme's own background.
  GoldenTestGroup themedGroup(Widget child) {
    return GoldenTestGroup(
      columns: 1,
      children: [
        for (final entry in {
          'light': AppTheme.light,
          'dark': AppTheme.dark,
        }.entries)
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
    'SectionHeader renders label and trailing',
    fileName: 'section_header',
    builder: () => themedGroup(
      const SectionHeader(label: 'July 2026', trailing: Text('View all 128')),
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

  // The one place the design system raises its voice: the display face against
  // the 11sp uppercase section labels it introduces. The golden pins that scale
  // relationship, which is the whole hierarchy — there is no rule or fill
  // behind it to carry the header on its own.
  goldenTest(
    'YearHeader over a month section label',
    fileName: 'year_header',
    builder: () => themedGroup(
      const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          YearHeader(year: 2026, count: 412),
          SizedBox(height: 8),
          SectionHeader(label: 'July 2026'),
          SizedBox(height: 16),
          YearHeader(year: 2025, count: 1),
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
    builder: () => themedGroup(LimitedAccessBanner(onSelectMore: () {})),
  );

  // The nav capsule's knob sits under the active destination; Search (index 1)
  // is selected so the golden pins the destination order, the knob offset and
  // the capsule's inverted-ink fill in both themes.
  goldenTest(
    'NavPillBar — Search selected',
    fileName: 'nav_pill_bar',
    builder: () => themedGroup(NavPillBar(currentIndex: 1, onTap: (_) {})),
  );

  goldenTest(
    'ThemeModePicker — system selected',
    fileName: 'theme_mode_picker',
    builder: () =>
        themedGroup(ThemeModePicker(mode: ThemeMode.system, onChanged: (_) {})),
  );

  // The consent switch is the only switch in the app; its active track is the
  // pill-active token, so this golden is what keeps consent from drifting into
  // a second accent color.
  goldenTest(
    'ConsentSwitch — on and off',
    fileName: 'consent_switch',
    builder: () => themedGroup(
      Row(
        children: [
          ConsentSwitch(value: true, onChanged: (_) {}, semanticLabel: 'On'),
          const SizedBox(width: 12),
          ConsentSwitch(value: false, onChanged: (_) {}, semanticLabel: 'Off'),
        ],
      ),
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
          photoLibraryServiceProvider.overrideWithValue(
            FakePhotoLibraryService(),
          ),
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

  // Dialogs are styled entirely by the theme's DialogThemeData /
  // TextButtonThemeData (r20 surface, hairline border, stadium text actions);
  // these goldens pin that styling so the six AlertDialog call sites can rely
  // on it with zero call-site styling. Built directly, never via showDialog.
  goldenTest(
    'AppDialog — confirm',
    fileName: 'app_dialog_confirm',
    builder: () => themedGroup(
      AlertDialog(
        title: const Text('Delete album?'),
        content: const Text(
          'Photos stay in your library. Only the album is removed.',
        ),
        actions: [
          TextButton(onPressed: () {}, child: const Text('Cancel')),
          TextButton(onPressed: () {}, child: const Text('Delete')),
        ],
      ),
    ),
  );

  // The unfocused TextField pins the themed filled input decoration
  // (surface2 fill, r12, no underline). Unfocused on purpose — a focused
  // field's cursor blink never settles under the test clock.
  goldenTest(
    'AppDialog — text input',
    fileName: 'app_dialog_input',
    builder: () => themedGroup(
      AlertDialog(
        title: const Text('New album'),
        content: const TextField(
          decoration: InputDecoration(hintText: 'Album name'),
        ),
        actions: [
          TextButton(onPressed: () {}, child: const Text('Cancel')),
          TextButton(onPressed: () {}, child: const Text('Create')),
        ],
      ),
    ),
  );

  // The sheet's surface and top-r20 shape come from the theme's
  // BottomSheetThemeData and only paint inside a real modal route, so this
  // golden pins the content column — grab handle, tracked-uppercase header,
  // and note — on the scenario's own background.
  goldenTest(
    'AppSheet — grab handle, header, note',
    fileName: 'app_sheet',
    builder: () => themedGroup(
      const AppSheet(
        label: 'ADD TO ALBUM',
        child: AppSheetNote('No albums yet — type a name above to make one.'),
      ),
    ),
  );

  // Same null-bytes fake: the placeholder cover isolates the card's own
  // treatment — the segment row, the scrim, and the overlaid title.
  goldenTest(
    'MemoryCard — titled and untitled cover',
    fileName: 'memory_card',
    builder: () => themedGroup(
      ProviderScope(
        overrides: [
          photoLibraryServiceProvider.overrideWithValue(
            FakePhotoLibraryService(),
          ),
        ],
        child: const Row(
          children: [
            MemoryCard(
              memory: MemorySummary(
                id: 1,
                kind: 'trip',
                title: 'Early June',
                subtitle: '2025',
                coverAssetId: 'x',
                assetCount: 24,
              ),
            ),
            SizedBox(width: 10),
            MemoryCard(
              memory: MemorySummary(
                id: 2,
                kind: 'onThisDay',
                title: 'On this day',
                subtitle: '2024',
                coverAssetId: null,
                assetCount: 6,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  // All three AppButton voices plus the busy primary. pumpOnce, not settle —
  // the busy spinner animates forever, and a single pump renders it at a
  // deterministic t=0.
  goldenTest(
    'AppButton — primary, busy, secondary, quiet',
    fileName: 'app_button',
    pumpBeforeTest: pumpOnce,
    builder: () => themedGroup(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppButton.primary(
            label: 'Allow photo access',
            expand: true,
            onPressed: () {},
          ),
          const SizedBox(height: 12),
          const AppButton.primary(
            label: 'Continue',
            busy: true,
            onPressed: null,
          ),
          const SizedBox(height: 12),
          AppButton.secondary(
            label: 'New album',
            icon: Icons.add_rounded,
            onPressed: () {},
          ),
          const SizedBox(height: 12),
          AppButton.quiet(
            label: 'View all 128',
            chevron: true,
            onPressed: () {},
          ),
        ],
      ),
    ),
  );

  goldenTest(
    'EmptyState — title with detail and CTA, and note',
    fileName: 'empty_state',
    builder: () => themedGroup(
      Column(
        children: [
          EmptyState(
            title: 'No albums yet',
            detail: 'Group photos your way. Tap + to make your first album.',
            action: AppButton.secondary(
              label: 'New album',
              icon: Icons.add_rounded,
              onPressed: () {},
            ),
          ),
          const SizedBox(height: 24),
          const EmptyState.note('No matches.'),
        ],
      ),
    ),
  );

  // Same null-bytes fake as AlbumCard: the "cover" row renders the flat
  // placeholder tile deterministically; the fallbackIcon row pins the glyph
  // treatment, and the last row omits the count entirely.
  goldenTest(
    'CoverRow — cover, fallback icon, no count',
    fileName: 'cover_row',
    builder: () => themedGroup(
      ProviderScope(
        overrides: [
          photoLibraryServiceProvider.overrideWithValue(
            FakePhotoLibraryService(),
          ),
        ],
        child: Column(
          children: [
            CoverRow(
              coverAssetId: 'x',
              name: 'Iceland 2026',
              count: 128,
              onTap: () {},
            ),
            CoverRow(
              coverAssetId: null,
              name: 'Camera',
              count: 1,
              fallbackIcon: Icons.photo_album_outlined,
              onTap: () {},
            ),
            CoverRow(coverAssetId: null, name: 'Family', onTap: () {}),
          ],
        ),
      ),
    ),
  );

  goldenTest(
    'SectionHeader — tappable variant with count and chevron',
    fileName: 'section_header_tappable',
    builder: () => themedGroup(
      SectionHeader(
        label: 'July 2026',
        trailing: const Text('12 items'),
        onTap: () {},
      ),
    ),
  );

  goldenTest(
    'AppCard — single child and divided rows',
    fileName: 'app_card',
    builder: () => themedGroup(
      const Column(
        children: [
          AppCard(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Search runs entirely on this device. Labels, text (OCR) and '
                'faces are indexed locally and never leave your phone.',
              ),
            ),
          ),
          SizedBox(height: 16),
          AppCard.divided(
            children: [
              Padding(padding: EdgeInsets.all(16), child: Text('Photos')),
              Padding(padding: EdgeInsets.all(16), child: Text('Videos')),
              Padding(padding: EdgeInsets.all(16), child: Text('People')),
            ],
          ),
        ],
      ),
    ),
  );

  // Two discs on a photo-grey band, so the over-media variant is judged against
  // something other than the page background it never sits on.
  goldenTest(
    'CircleIconButton — over-media and surface',
    fileName: 'circle_icon_button',
    builder: () => themedGroup(
      Row(
        children: [
          ColoredBox(
            color: const Color(0xFF7A7A72),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  CircleIconButton.overMedia(
                    icon: Icons.arrow_back_rounded,
                    tooltip: 'Back',
                    onPressed: () {},
                  ),
                  const SizedBox(width: 8),
                  CircleIconButton.overMedia(
                    icon: Icons.favorite_rounded,
                    tooltip: 'Favorite',
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          CircleIconButton.surface(
            icon: Icons.settings_rounded,
            tooltip: 'Settings',
            onPressed: () {},
          ),
        ],
      ),
    ),
  );

  goldenTest(
    'SegmentedControl — first, middle and last selected',
    fileName: 'segmented_control',
    builder: () => themedGroup(
      Column(
        children: [
          for (final selected in ThemeMode.values) ...[
            SegmentedControl<ThemeMode>(
              options: ThemeMode.values,
              value: selected,
              labelBuilder: (m) => switch (m) {
                ThemeMode.system => 'System',
                ThemeMode.light => 'Light',
                ThemeMode.dark => 'Dark',
              },
              onChanged: (_) {},
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    ),
  );

  // The app-wide analysis strip: a caption on `surface2` with a hairline rule
  // and the progress line along its bottom edge. Pinned in both themes because
  // it sits above every screen, so a contrast slip would show everywhere.
  goldenTest(
    'IndexingBanner — a pass three quarters done',
    fileName: 'indexing_banner',
    builder: () => themedGroup(
      ProviderScope(
        overrides: [
          indexingStatusProvider.overrideWithValue(
            const AsyncData(IndexingStatus(remaining: 250, total: 1000)),
          ),
        ],
        child: const IndexingBanner(),
      ),
    ),
  );

  // The People strip as it appears on Search idle and Albums: a card, circular
  // faces, and a caption band that only exists because someone is named. Every
  // cover resolves to null here (as it does in any host test — no decodable
  // thumbnail), so the golden pins the placeholder circles, the card and the
  // spacing rather than image content.
  goldenTest(
    'PeopleStrip — carded row of circular faces, one named',
    fileName: 'people_strip',
    builder: () => themedGroup(
      ProviderScope(
        overrides: [
          for (final id in [1, 2, 3, 4])
            personCoverProvider(id).overrideWith((ref) async => null),
        ],
        child: PeopleStrip(
          people: const [
            PersonSummary(
              id: 1,
              displayName: 'Ada',
              coverAssetId: 'a',
              faceCount: 12,
            ),
            PersonSummary(
              id: 2,
              displayName: null,
              coverAssetId: 'b',
              faceCount: 4,
            ),
            PersonSummary(
              id: 3,
              displayName: null,
              coverAssetId: 'c',
              faceCount: 3,
            ),
            PersonSummary(
              id: 4,
              displayName: null,
              coverAssetId: 'd',
              faceCount: 1,
            ),
          ],
        ),
      ),
    ),
  );

  goldenTest(
    'AppButton — compact primary with a leading icon',
    fileName: 'app_button_compact',
    builder: () => themedGroup(
      Row(
        children: [
          AppButton.primary(
            label: 'New',
            icon: Icons.add_rounded,
            compact: true,
            onPressed: () {},
          ),
        ],
      ),
    ),
  );
}
