import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../widgets/app_card.dart';
import '../../folders/folders_providers.dart';
import '../../settings/widgets/settings_rows.dart';
import 'inherited_consent_scope.dart';

/// The folder-scope card on the consent step. Watches the device folders so
/// the summary and selected-photo count update as the user opens/closes the
/// picker. The picker itself is shared with Settings → Analysis.
class FolderScopeCard extends ConsumerWidget {
  const FolderScopeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = InheritedConsentScope.of(context);
    final foldersAsync = ref.watch(deviceFoldersProvider);
    final folders = foldersAsync.whenOrNull(data: (v) => v) ?? const [];

    final includedFolders = [
      for (final f in folders)
        if (!state.excludedFolderIds.contains(f.id)) f,
    ];
    final selectedCount = includedFolders.fold(0, (sum, f) => sum + f.count);
    final totalFolders = folders.length;
    final includedFoldersCount = includedFolders.length;

    final summary = state.excludedFolderIds.isEmpty || totalFolders == 0
        ? 'All folders'
        : '$includedFoldersCount of $totalFolders folders';

    final analysisEnabled = state.search || state.memories || state.faces;
    final photos =
        '$selectedCount ${_pluralize(selectedCount, 'photo', 'photos')}';
    // The "a while" warning is only honest at a size where it is true. Shown
    // unconditionally it read the same for 66 photos as for 892, which turns it
    // into noise on exactly the selections the folder picker exists to make.
    final caption = !analysisEnabled
        ? 'No on-device analysis is turned on.'
        : selectedCount == 0
        ? 'No photos selected to analyze.'
        : selectedCount >= _slowAnalysisThreshold
        ? '$photos. This may take a while.'
        : '$photos.';

    return AppCard.divided(
      children: [
        SettingsActionRow(
          label: 'Folders to analyze',
          caption: 'Excluded folders stay visible; their photos are skipped.',
          onTap: state.onOpenFolderPicker,
        ),
        SettingsCaptionRow('$summary · $caption'),
      ],
    );
  }

  /// Above this many photos the first analysis pass is long enough to be worth
  /// warning about; below it the warning is just noise. Measured on a Pixel 9
  /// Pro XL with search + faces on, a pass runs at roughly one photo a second,
  /// so this is about the point where it stops finishing inside a minute.
  static const _slowAnalysisThreshold = 100;

  static String _pluralize(int count, String singular, String plural) =>
      count == 1 ? singular : plural;
}
