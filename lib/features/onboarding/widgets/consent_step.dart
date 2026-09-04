import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_space.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/consent_switch.dart';
import 'brand_mark.dart';
import 'folder_scope_card.dart';
import 'inherited_consent_scope.dart';

/// Step 2: which on-device features to turn on. Deliberately the same
/// skeleton as step 1 — same eyebrow, headline scale, row rhythm, and pill
/// CTA — so it reads as the rest of one promise rather than a bolted-on
/// permission wall. The rows are [Assurance]'s anatomy with the leading dot
/// traded for a trailing switch: same voice, but now the user answers.
class ConsentStep extends StatelessWidget {
  const ConsentStep({
    super.key,
    required this.busy,
    required this.search,
    required this.memories,
    required this.faces,
    required this.excludedFolderIds,
    required this.onSearchChanged,
    required this.onMemoriesChanged,
    required this.onFacesChanged,
    required this.onOpenFolderPicker,
    required this.onContinue,
  });

  final bool busy;
  final bool search;
  final bool memories;
  final bool faces;
  final Set<String> excludedFolderIds;
  final ValueChanged<bool> onSearchChanged;
  final ValueChanged<bool> onMemoriesChanged;
  final ValueChanged<bool> onFacesChanged;
  final VoidCallback onOpenFolderPicker;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final text = Theme.of(context).extension<AppTextStyles>()!;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          // Horizontal inset normalized from 28 to the s24 step (approved
          // Phase-1e decision).
          padding: const EdgeInsets.fromLTRB(
            AppSpace.s24,
            AppSpace.s24,
            AppSpace.s24,
            AppSpace.s20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const BrandMark(),
                  const SizedBox(width: AppSpace.s12),
                  Text(
                    'SoloGallery',
                    style: text.sectionLabel.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
              // Scrollable rather than Spacer-padded: three switch rows plus
              // the headline overflow a short screen at large font scales, and
              // a RenderFlex overflow is a hard failure on device.
              Expanded(
                child: InheritedConsentScope(
                  search: search,
                  memories: memories,
                  faces: faces,
                  excludedFolderIds: excludedFolderIds,
                  onOpenFolderPicker: onOpenFolderPicker,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: AppSpace.s32),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'What should stay\non the shelf?',
                              style: text.display.copyWith(
                                color: scheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              'SoloGallery can look through your photos to '
                              'make them easier to find. It all happens on '
                              'this device — and none of it starts until you '
                              'say so.',
                              style: text.body.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpace.s32),
                        _ConsentToggle(
                          label: 'CONTENT SEARCH',
                          detail:
                              'Find photos by what is in them, and by '
                              'text they contain',
                          value: search,
                          onChanged: onSearchChanged,
                        ),
                        _ConsentToggle(
                          label: 'MEMORIES',
                          detail:
                              'Occasional highlights built from photos '
                              'you already have',
                          value: memories,
                          onChanged: onMemoriesChanged,
                        ),
                        _ConsentToggle(
                          label: 'FACE DETECTION',
                          detail:
                              "Groups photos by who's in them. Faces "
                              'never leave this device.',
                          value: faces,
                          onChanged: onFacesChanged,
                        ),
                        const SizedBox(height: AppSpace.s24),
                        const FolderScopeCard(),
                        const SizedBox(height: AppSpace.s8),
                      ],
                    ),
                  ),
                ),
              ),
              Column(
                children: [
                  AppButton.primary(
                    label: 'Continue',
                    busy: busy,
                    expand: true,
                    onPressed: busy ? null : onContinue,
                  ),
                  const SizedBox(height: 14),
                  Center(
                    child: Text(
                      'Your photos open next either way.',
                      textAlign: TextAlign.center,
                      style: text.caption.copyWith(color: colors.textMuted),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A consent row: [Assurance]'s tracked-uppercase label over a plain-language
/// detail, with a switch where the hairline dot would be. The switch is the
/// row's only marker — a dot as well would be two signals for one row.
class _ConsentToggle extends StatelessWidget {
  const _ConsentToggle({
    required this.label,
    required this.detail,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String detail;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final text = Theme.of(context).extension<AppTextStyles>()!;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: text.sectionLabel.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  detail,
                  style: text.caption.copyWith(color: colors.textSecondary),
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
