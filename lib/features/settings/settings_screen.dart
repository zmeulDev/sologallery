import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../services/indexing_service.dart';
import '../../services/permission_provider.dart';
import '../../services/photo_library_service.dart';
import 'settings_providers.dart';
import 'theme_mode_provider.dart';
import 'widgets/theme_mode_picker.dart';

/// The Settings tab: photo access, library stats, index rebuild, appearance,
/// and about. Reads app-wide providers; every persisted change (theme) goes
/// through Drift via [SettingsDao].
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final styles = Theme.of(context).extension<AppTextStyles>()!;
    return Scaffold(
      appBar: AppBar(title: Text('Settings', style: styles.pageTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: const [
          _PhotoAccessGroup(),
          _LibraryGroup(),
          _IndexGroup(),
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
    return _Group(
      label: 'Photo access',
      child: _Card(
        children: [
          _InfoRow(label: _accessTitle(access), value: null),
          _CaptionRow(_accessCaption(access)),
          if (access == PhotoAccess.limited)
            _ActionRow(
              label: 'Select more photos',
              onTap: controller.presentLimited,
            ),
          if (access != PhotoAccess.granted)
            _ActionRow(
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

    final images = totals.whenOrNull(
      data: (t) => (t.photos - t.videos).toString(),
    );
    final videos = totals.whenOrNull(data: (t) => t.videos.toString());
    final peopleCount = people.whenOrNull(data: (n) => n.toString());
    final analysis = status.whenOrNull(
      data: (s) => s.isIndexing ? 'Analyzing… ${s.remaining} left' : 'Up to date',
    );

    return _Group(
      label: 'Library',
      child: _Card(
        children: [
          _InfoRow(label: 'Photos', value: images ?? '—'),
          _InfoRow(label: 'Videos', value: videos ?? '—'),
          _InfoRow(label: 'People', value: peopleCount ?? '—'),
          _InfoRow(label: 'Analysis', value: analysis ?? '—'),
        ],
      ),
    );
  }
}

// --- Rebuild index ---------------------------------------------------------

class _IndexGroup extends ConsumerWidget {
  const _IndexGroup();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _Group(
      label: 'Index',
      child: _Card(
        children: [
          _ActionRow(
            label: 'Rebuild index',
            caption: 'Re-scan the library and re-run on-device analysis.',
            onTap: () => _confirmRebuild(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRebuild(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rebuild index?'),
        content: const Text(
          'Re-scans your whole library and re-runs on-device analysis — labels, '
          'text, and people. Your photos are never changed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Rebuild'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await ref.read(indexingServiceProvider).rebuild();
    }
  }
}

// --- Appearance ------------------------------------------------------------

class _AppearanceGroup extends ConsumerWidget {
  const _AppearanceGroup();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider).value ?? ThemeMode.system;
    return _Group(
      label: 'Appearance',
      child: _Card(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: ThemeModePicker(
              mode: mode,
              onChanged: (next) =>
                  ref.read(settingsDaoProvider).setThemeMode(next),
            ),
          ),
        ],
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
    return _Group(
      label: 'About',
      child: _Card(
        children: [
          _InfoRow(label: 'SoloGallery', value: version ?? '—'),
          _CaptionRow(
            '100% on-device. Zero network. Your photos never leave this device.',
          ),
        ],
      ),
    );
  }
}

// --- Shared building blocks ------------------------------------------------

/// A titled settings group: the tracked-uppercase section label (the design
/// system's typographic signature) above a surface card.
class _Group extends StatelessWidget {
  const _Group({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final styles = Theme.of(context).extension<AppTextStyles>()!;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              label.toUpperCase(),
              style: styles.sectionLabel.copyWith(color: scheme.onSurface),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

/// A rounded surface card that hairline-divides its [children].
class _Card extends StatelessWidget {
  const _Card({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 1, color: colors.border),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// A label + optional trailing value row.
class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final styles = Theme.of(context).extension<AppTextStyles>()!;
    final colors = Theme.of(context).extension<AppColors>()!;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: styles.body.copyWith(color: scheme.onSurface),
            ),
          ),
          if (value != null)
            Text(
              value!,
              style: styles.exifValue.copyWith(color: colors.textSecondary),
            ),
        ],
      ),
    );
  }
}

/// A supporting caption row under an info row.
class _CaptionRow extends StatelessWidget {
  const _CaptionRow(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final styles = Theme.of(context).extension<AppTextStyles>()!;
    final colors = Theme.of(context).extension<AppColors>()!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Text(
        text,
        style: styles.caption.copyWith(color: colors.textMuted),
      ),
    );
  }
}

/// A tappable action row (label + optional caption + chevron).
class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.label, this.caption, required this.onTap});

  final String label;
  final String? caption;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final styles = Theme.of(context).extension<AppTextStyles>()!;
    final colors = Theme.of(context).extension<AppColors>()!;
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: styles.body.copyWith(color: scheme.onSurface),
                  ),
                  if (caption != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      caption!,
                      style: styles.caption.copyWith(color: colors.textMuted),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 20, color: colors.textMuted),
          ],
        ),
      ),
    );
  }
}
