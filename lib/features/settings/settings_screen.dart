import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/database_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_space.dart';
import '../../core/theme/app_text_styles.dart';
import '../../widgets/app_card.dart';
import '../../services/indexing_service.dart';
import '../../services/permission_provider.dart';
import '../../services/photo_library_service.dart';
import 'consent_provider.dart';
import 'settings_providers.dart';
import 'theme_mode_provider.dart';
import 'widgets/settings_rows.dart';
import 'widgets/theme_mode_picker.dart';

/// The Settings tab: photo access, library stats, index rebuild, appearance,
/// and about. Reads app-wide providers; every persisted change (theme) goes
/// through Drift via [SettingsDao].
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final styles = Theme.of(context).extension<AppTextStyles>()!;
    final colors = Theme.of(context).extension<AppColors>()!;
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings', style: styles.pageTitle),
        // Settings is the one screen that is a list all the way down, with no
        // photo to establish where the header ends — the hairline does it.
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: colors.border),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.s16,
          AppSpace.s8,
          AppSpace.s16,
          AppSpace.s32,
        ),
        children: const [
          _PhotoAccessGroup(),
          _LibraryGroup(),
          _AnalysisGroup(),
          _AppearanceGroup(),
          _AboutGroup(),
        ],
      ),
    );
  }
}

// --- Photo access ----------------------------------------------------------

class _PhotoAccessGroup extends ConsumerWidget {
  const _PhotoAccessGroup();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(permissionProvider);
    final controller = ref.read(permissionProvider.notifier);
    return SettingsGroup(
      label: 'Photo access',
      child: AppCard.divided(
        children: [
          SettingsInfoRow(label: _accessTitle(access), value: null),
          SettingsCaptionRow(_accessCaption(access)),
          if (access == PhotoAccess.limited)
            SettingsActionRow(
              label: 'Select more photos',
              onTap: controller.presentLimited,
            ),
          if (access != PhotoAccess.granted)
            SettingsActionRow(
              label: 'Open system settings',
              onTap: controller.openSettings,
            ),
        ],
      ),
    );
  }

  static String _accessTitle(PhotoAccess access) => switch (access) {
    PhotoAccess.granted => 'Full access',
    PhotoAccess.limited => 'Limited access',
    PhotoAccess.denied => 'No access',
    PhotoAccess.notDetermined => 'Not set',
  };

  static String _accessCaption(PhotoAccess access) => switch (access) {
    PhotoAccess.granted => 'SoloGallery can see your whole library.',
    PhotoAccess.limited => 'Only the photos you selected are visible.',
    PhotoAccess.denied => "SoloGallery can't see your photos.",
    PhotoAccess.notDetermined => 'Grant access to browse your photos.',
  };
}

// --- Library stats ---------------------------------------------------------

class _LibraryGroup extends ConsumerWidget {
  const _LibraryGroup();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totals = ref.watch(libraryTotalsProvider);
    final people = ref.watch(peopleCountProvider);
    final status = ref.watch(indexingStatusProvider);
    // With face detection off there are no clusters to count, and a bare "0"
    // reads as a bug rather than a choice — the row goes away instead.
    final facesOn = ref.watch(facesEnabledProvider).value ?? false;

    final images = totals.whenOrNull(
      data: (t) => (t.photos - t.videos).toString(),
    );
    final videos = totals.whenOrNull(data: (t) => t.videos.toString());
    final peopleCount = people.whenOrNull(data: (n) => n.toString());
    // "Up to date" would imply analysis happened. With nothing consented none
    // runs at all, so the row has to say that rather than imply a finished job.
    final searchOn = ref.watch(searchEnabledProvider).value ?? false;
    final analysis = (!searchOn && !facesOn)
        ? 'Off'
        : status.whenOrNull(
            data: (s) =>
                s.isIndexing ? 'Analyzing… ${s.remaining} left' : 'Up to date',
          );

    return SettingsGroup(
      label: 'Library',
      child: AppCard.divided(
        children: [
          SettingsInfoRow(label: 'Photos', value: images ?? '—'),
          SettingsInfoRow(label: 'Videos', value: videos ?? '—'),
          if (facesOn) SettingsInfoRow(label: 'People', value: peopleCount ?? '—'),
          SettingsInfoRow(label: 'Status', value: analysis ?? '—'),
        ],
      ),
    );
  }
}

// --- Analysis --------------------------------------------------------------

/// Entry point to the dedicated Analysis settings sub-screen, where the
/// on-device analysis consents, index rebuild, and folder scope all live.
class _AnalysisGroup extends ConsumerWidget {
  const _AnalysisGroup();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SettingsGroup(
      label: 'Analysis',
      child: AppCard.divided(
        children: [
          SettingsActionRow(
            label: 'Analysis',
            caption:
                'On-device analysis, index rebuild, and folders to analyze.',
            onTap: () => context.push('/settings/analysis'),
          ),
        ],
      ),
    );
  }
}

// --- Appearance ------------------------------------------------------------

class _AppearanceGroup extends ConsumerWidget {
  const _AppearanceGroup();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider).value ?? ThemeMode.system;
    // No card around this one: the segmented control brings its own recessed
    // track, and a card would be a container inside a container.
    return SettingsGroup(
      label: 'Appearance',
      child: ThemeModePicker(
        mode: mode,
        onChanged: (next) => ref.read(settingsDaoProvider).setThemeMode(next),
      ),
    );
  }
}

// --- About -----------------------------------------------------------------

class _AboutGroup extends ConsumerWidget {
  const _AboutGroup();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final version = ref.watch(appVersionProvider).whenOrNull(data: (v) => v);
    return SettingsGroup(
      label: 'About',
      child: AppCard.divided(
        children: [
          SettingsInfoRow(label: 'SoloGallery', value: version ?? '—'),
          SettingsCaptionRow(
            '100% on-device. Zero network. Your photos never leave this device.',
          ),
        ],
      ),
    );
  }
}

