import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_space.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../widgets/consent_switch.dart';

/// A titled settings group: the tracked-uppercase section label (the design
/// system's typographic signature) above a surface card.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final styles = Theme.of(context).extension<AppTextStyles>()!;
    final colors = Theme.of(context).extension<AppColors>()!;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.s20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: AppSpace.s4, bottom: 10),
            child: Text(
              label.toUpperCase(),
              // Quieter than a Library section header: these label a settings
              // group the reader is scanning past, not content they came for.
              style: styles.sectionLabel.copyWith(color: colors.textSecondary),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

/// A label + optional trailing value row.
class SettingsInfoRow extends StatelessWidget {
  const SettingsInfoRow({super.key, required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final styles = Theme.of(context).extension<AppTextStyles>()!;
    final colors = Theme.of(context).extension<AppColors>()!;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.s16,
        vertical: 14,
      ),
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
class SettingsCaptionRow extends StatelessWidget {
  const SettingsCaptionRow(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final styles = Theme.of(context).extension<AppTextStyles>()!;
    final colors = Theme.of(context).extension<AppColors>()!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpace.s16, 0, AppSpace.s16, 14),
      child: Text(
        text,
        style: styles.caption.copyWith(color: colors.textMuted),
      ),
    );
  }
}

/// A toggle row: [SettingsActionRow]'s anatomy with a switch where the chevron sits,
/// so the trailing element always says what the row does — chevron navigates,
/// switch toggles.
class SettingsSwitchRow extends StatelessWidget {
  const SettingsSwitchRow({
    super.key,
    required this.label,
    required this.caption,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String caption;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final styles = Theme.of(context).extension<AppTextStyles>()!;
    final colors = Theme.of(context).extension<AppColors>()!;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.s16,
        vertical: 14,
      ),
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
                const SizedBox(height: 3),
                Text(
                  caption,
                  style: styles.caption.copyWith(color: colors.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpace.s16),
          ConsentSwitch(
            value: value,
            onChanged: onChanged,
            semanticLabel: label,
          ),
        ],
      ),
    );
  }
}

/// A tappable action row (label + optional caption + chevron).
class SettingsActionRow extends StatelessWidget {
  const SettingsActionRow({
    super.key,
    required this.label,
    this.caption,
    required this.onTap,
  });

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
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s16,
          vertical: 14,
        ),
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
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: colors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}
