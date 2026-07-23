import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_space.dart';
import '../../core/theme/app_text_styles.dart';
import '../../services/indexing_service.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_dialog.dart';
import 'consent_provider.dart';
import '../folders/folders_providers.dart';
import 'settings_providers.dart';
import 'widgets/folder_picker_sheet.dart';
import 'widgets/settings_rows.dart';

/// The dedicated Analysis settings screen: on-device analysis consents,
/// index rebuild, and the folder scope that controls which device folders are
/// analyzed. Excluded folders remain visible everywhere else in the app.
class AnalysisSettingsScreen extends ConsumerWidget {
  const AnalysisSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final styles = Theme.of(context).extension<AppTextStyles>()!;
    final colors = Theme.of(context).extension<AppColors>()!;
    final excluded = ref.watch(excludedFolderIdsProvider).value ?? const <String>{};
    final folders = ref.watch(deviceFoldersProvider);
    final totalFolders = folders.whenOrNull(data: (v) => v.length) ?? 0;

    final folderSummary = excluded.isEmpty
        ? 'All folders'
        : '${totalFolders - excluded.length} of $totalFolders folders';

    return Scaffold(
      appBar: AppBar(
        title: Text('Analysis', style: styles.pageTitle),
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
        children: [
          const _OnDeviceGroup(),
          const _IndexGroup(),
          _FoldersGroup(
            summary: folderSummary,
            excluded: excluded,
          ),
        ],
      ),
    );
  }
}

// --- On-device analysis ------------------------------------------------------

/// The consent toggles, mirroring what onboarding asked. Turning one off
/// deletes what it derived; the side effects live on [IndexingService] so both
/// entry points share one implementation.
class _OnDeviceGroup extends ConsumerWidget {
  const _OnDeviceGroup();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final search = ref.watch(searchEnabledProvider).value ?? false;
    final memories = ref.watch(memoriesEnabledProvider).value ?? false;
    final faces = ref.watch(facesEnabledProvider).value ?? false;
    final indexing = ref.read(indexingServiceProvider);

    // One card per toggle. These three are independent grants, not facets of
    // one setting, and a divided stack reads as a single block the user accepts
    // or refuses wholesale — exactly the impression a consent surface must not
    // give.
    return SettingsGroup(
      label: 'On-device analysis',
      child: Column(
        children: [
          AppCard(
            child: SettingsSwitchRow(
              label: 'Content search',
              caption:
                  'Find photos by what is in them, and by text they '
                  'contain. Turning this off deletes what was found.',
              value: search,
              onChanged: indexing.setSearchEnabled,
            ),
          ),
          const SizedBox(height: AppSpace.s8),
          AppCard(
            child: SettingsSwitchRow(
              label: 'Memories',
              caption:
                  'Occasional highlights built from photos you already have.',
              value: memories,
              onChanged: indexing.setMemoriesEnabled,
            ),
          ),
          const SizedBox(height: AppSpace.s8),
          AppCard(
            child: SettingsSwitchRow(
              label: 'Face detection',
              caption:
                  "Groups photos by who's in them. Turning this off deletes "
                  'the faces already found.',
              value: faces,
              onChanged: indexing.setFacesEnabled,
            ),
          ),
        ],
      ),
    );
  }
}

// --- Rebuild index -----------------------------------------------------------

class _IndexGroup extends ConsumerWidget {
  const _IndexGroup();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SettingsGroup(
      label: 'Index',
      child: AppCard.divided(
        children: [
          SettingsActionRow(
            label: 'Rebuild index',
            caption: 'Re-scan the library and re-run on-device analysis.',
            onTap: () => _confirmRebuild(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRebuild(BuildContext context, WidgetRef ref) async {
    // Name only what is actually switched on — promising to re-run "labels,
    // text, and people" when the user declined them describes work that will
    // not happen.
    final enabled = [
      if (ref.read(searchEnabledProvider).value ?? false) 'labels and text',
      if (ref.read(facesEnabledProvider).value ?? false) 'people',
    ];
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Rebuild index?',
      message: enabled.isEmpty
          ? 'Re-scans your whole library. No on-device analysis is turned '
                'on, so nothing is analyzed. Your photos are never changed.'
          : 'Re-scans your whole library and re-runs on-device analysis — '
                '${enabled.join(' and ')}. Your photos are never changed.',
      confirmLabel: 'Rebuild',
    );
    if (confirmed) {
      await ref.read(indexingServiceProvider).rebuild();
    }
  }
}

// --- Folders for indexing ----------------------------------------------------

class _FoldersGroup extends ConsumerWidget {
  const _FoldersGroup({required this.summary, required this.excluded});

  final String summary;
  final Set<String> excluded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SettingsGroup(
      label: 'Folders for indexing',
      child: AppCard.divided(
        children: [
          SettingsActionRow(
            label: 'Folders to analyze',
            caption:
                'Excluded folders stay visible in the library; their photos '
                'just are not analyzed.',
            onTap: () => _openPicker(context, ref),
          ),
          SettingsInfoRow(label: 'Selected', value: summary),
        ],
      ),
    );
  }

  Future<void> _openPicker(BuildContext context, WidgetRef ref) async {
    final result = await FolderPickerSheet.show(
      context,
      initialExcluded: excluded,
    );
    if (result != null && !context.mounted) return;
    if (result != null) {
      await ref.read(indexingServiceProvider).setExcludedFolderIds(result);
    }
  }
}
