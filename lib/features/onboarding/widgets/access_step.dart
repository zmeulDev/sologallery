import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_space.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../services/photo_library_service.dart';
import '../../../widgets/app_button.dart';
import 'access_ring.dart';
import 'assurance.dart';
import 'brand_mark.dart';

/// Step 1 of onboarding: the app's one promise — photos never leave the
/// device — then the library-access request. See `OnboardingScreen` for how
/// the two steps fit together.
class AccessStep extends StatelessWidget {
  const AccessStep({
    super.key,
    required this.access,
    required this.attempted,
    required this.busy,
    required this.onRequestAccess,
    required this.onOpenSettings,
  });

  final PhotoAccess access;

  /// Whether a prompt has already been shown this session — see
  /// `_OnboardingScreenState._attempted`.
  final bool attempted;
  final bool busy;
  final VoidCallback onRequestAccess;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final text = Theme.of(context).extension<AppTextStyles>()!;
    final scheme = Theme.of(context).colorScheme;
    // Show the Settings path only once a prompt has actually been refused;
    // before that (including Android's never-asked "denied") we invite the
    // native request dialog.
    final denied = attempted && access == PhotoAccess.denied;
    // Fraction of screen width, not a fixed pixel value, so the ring scales
    // with the device instead of clipping identically on every width.
    final diameter = MediaQuery.sizeOf(context).width * 1.1;

    return Scaffold(
      body: Stack(
        children: [
          Positioned(
            top: -diameter * 0.3,
            right: -diameter * 0.3,
            child: IgnorePointer(
              child: ExcludeSemantics(child: AccessRing(diameter: diameter)),
            ),
          ),
          SafeArea(
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
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        denied
                            ? 'Photo access is\nturned off.'
                            : 'Your photos\nstay yours.',
                        style: text.display.copyWith(color: scheme.onSurface),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        denied
                            ? 'SoloGallery needs access to your library to show '
                                  'your photos. Turn it on in Settings — nothing '
                                  'is uploaded, ever.'
                            : 'SoloGallery organizes everything right here on '
                                  'this device. No cloud, no account, no network '
                                  '— your library never leaves your phone.',
                        style: text.body.copyWith(color: colors.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.s32),
                  const Assurance(
                    label: 'LOCAL ONLY',
                    detail: 'Nothing is uploaded or synced',
                  ),
                  Assurance(
                    label: 'ON DEVICE',
                    detail: 'Search and organizing run on your phone',
                    color: colors,
                  ),
                  const Assurance(
                    label: 'NON-DESTRUCTIVE',
                    detail: 'Your original photos are never altered',
                  ),
                  const Spacer(),
                  Column(
                    children: [
                      AppButton.primary(
                        label: denied ? 'Open Settings' : 'Continue',
                        busy: busy,
                        expand: true,
                        onPressed: busy
                            ? null
                            : (denied ? onOpenSettings : onRequestAccess),
                      ),
                      const SizedBox(height: 14),
                      Center(
                        child: Text(
                          denied
                              ? 'We\'ll open the library the moment access is on.'
                              : 'You choose what to share — all photos or only '
                                    'some.',
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
        ],
      ),
    );
  }
}
