import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_space.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../services/photo_library_service.dart' show DeviceFolder;
import '../../../widgets/app_button.dart';
import '../../../widgets/app_sheet.dart';
import '../../folders/folders_providers.dart';

/// Lets the user pick which device folders are included in on-device analysis.
/// Returns the set of *excluded* folder ids, or null if the user dismisses the
/// sheet without tapping Done.
class FolderPickerSheet extends ConsumerStatefulWidget {
  const FolderPickerSheet({super.key, required this.initialExcluded});

  final Set<String> initialExcluded;

  static Future<Set<String>?> show(
    BuildContext context, {
    required Set<String> initialExcluded,
  }) {
    return showAppSheet<Set<String>>(
      context,
      isScrollControlled: true,
      builder: (context) => FolderPickerSheet(initialExcluded: initialExcluded),
    );
  }

  @override
  ConsumerState<FolderPickerSheet> createState() => _FolderPickerSheetState();
}

class _FolderPickerSheetState extends ConsumerState<FolderPickerSheet> {
  late Set<String> _excluded;

  @override
  void initState() {
    super.initState();
    _excluded = Set.of(widget.initialExcluded);
  }

  void _setAll({required bool included}) {
    setState(() {
      if (included) {
        _excluded = const {};
      } else {
        final folders = ref.read(deviceFoldersProvider).whenOrNull(data: (v) => v);
        if (folders != null) {
          _excluded = {for (final f in folders) f.id};
        }
      }
    });
  }

  void _setFolder(String id, {required bool included}) {
    setState(() {
      if (included) {
        _excluded.remove(id);
      } else {
        _excluded.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final foldersAsync = ref.watch(deviceFoldersProvider);

    final folders = foldersAsync.whenOrNull(data: (v) => v) ?? const <DeviceFolder>[];
    final allSelected = _excluded.isEmpty;

    return AppSheet(
      label: 'FOLDERS TO ANALYZE',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CheckboxRow(
            label: 'All folders',
            checked: allSelected,
            onChanged: (_) => _setAll(included: !allSelected),
          ),
          Divider(height: 1, color: colors.border),
          Flexible(
            child: foldersAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpace.s24),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (e, _) => AppSheetNote('Could not load folders: $e'),
              data: (_) => folders.isEmpty
                  ? const AppSheetNote('No folders found.')
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const ClampingScrollPhysics(),
                      itemCount: folders.length,
                      itemBuilder: (context, index) {
                        final folder = folders[index];
                        final included = !_excluded.contains(folder.id);
                        return _CheckboxRow(
                          label: folder.name,
                          caption: _countCaption(folder.count),
                          checked: included,
                          onChanged: (checked) => _setFolder(
                            folder.id,
                            included: checked ?? false,
                          ),
                        );
                      },
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpace.s16),
            child: AppButton.primary(
              label: 'Done',
              expand: true,
              onPressed: () => Navigator.of(context).pop(_excluded),
            ),
          ),
        ],
      ),
    );
  }

  static String _countCaption(int count) =>
      count == 1 ? '1 item' : '$count items';
}

class _CheckboxRow extends StatelessWidget {
  const _CheckboxRow({
    required this.label,
    required this.checked,
    required this.onChanged,
    this.caption,
  });

  final String label;
  final String? caption;
  final bool checked;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final styles = Theme.of(context).extension<AppTextStyles>()!;
    final scheme = Theme.of(context).colorScheme;

    // The row is one control, so it carries the checked state itself and the
    // Checkbox is excluded rather than contributing a second, separately
    // focusable node. Without this the row reports neither name nor state — the
    // selection is invisible to a screen reader and to semantics finders.
    return Semantics(
      checked: checked,
      label: caption == null ? label : '$label, $caption',
      onTap: () => onChanged(!checked),
      child: InkWell(
        onTap: () => onChanged(!checked),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.s16,
            vertical: 12,
          ),
          child: Row(
            children: [
              Expanded(
                child: ExcludeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: styles.body.copyWith(color: scheme.onSurface),
                      ),
                      if (caption != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          caption!,
                          style: styles.caption.copyWith(
                            color: colors.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              ExcludeSemantics(
                child: Checkbox(
                  value: checked,
                  onChanged: onChanged,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
