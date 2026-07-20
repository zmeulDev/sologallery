import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_space.dart';
import '../../core/theme/app_text_styles.dart';
import '../../services/permission_provider.dart';
import '../../services/photo_library_service.dart';
import '../../widgets/app_button.dart';
import '../../widgets/consent_switch.dart';
import '../settings/consent_provider.dart';

/// First-run gate, in two steps. The router sends the user here whenever the app
/// lacks library access *or* still owes the analysis-consent question (see
/// `app_router.dart` redirect).
///
/// Step 1 leads with the app's one promise — photos never leave the device —
/// then asks for access. Step 2 asks which on-device features to turn on; both
/// are off until chosen. When both are settled the redirect moves the user on to
/// the Library.
///
/// The step is derived from [permissionProvider] + [consentProvider] rather than
/// held locally, so access revoked mid-flow correctly falls back to step 1.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  bool _busy = false;

  /// Whether we've already prompted this session. On Android there is no
  /// "not determined" state — [PhotoAccess.denied] means both "never asked" and
  /// "refused", so we only offer the Settings path *after* a real prompt.
  bool _attempted = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// The step-2 answers. All start off: consent is a choice the user makes,
  /// not one they have to undo.
  bool _search = false;
  bool _memories = false;
  bool _faces = false;

  Future<void> _requestAccess() async {
    await ref.read(permissionProvider.notifier).request();
    if (mounted) setState(() => _attempted = true);
  }

  Future<void> _recordConsent() {
    return ref.read(consentProvider.notifier).record(
          search: _search,
          memories: _memories,
          faces: _faces,
        );
  }

  @override
  Widget build(BuildContext context) {
    final access = ref.watch(permissionProvider);
    if (access.canReadLibrary &&
        ref.watch(consentProvider) == ConsentState.needed) {
      return _buildConsentStep(context);
    }
    return _buildAccessStep(context, access);
  }

  Widget _buildAccessStep(BuildContext context, PhotoAccess access) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final text = Theme.of(context).extension<AppTextStyles>()!;
    final scheme = Theme.of(context).colorScheme;
    // Show the Settings path only once a prompt has actually been refused;
    // before that (including Android's never-asked "denied") we invite the
    // native request dialog.
    final denied = _attempted && access == PhotoAccess.denied;

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
              Text(
                'SoloGallery',
                style: text.sectionLabel.copyWith(color: colors.textSecondary),
              ),
              const Spacer(),
              Text(
                denied
                    ? 'Photo access is\nturned off.'
                    : 'Your photos\nstay yours.',
                style: text.display.copyWith(color: scheme.onSurface),
              ),
              const SizedBox(height: 18),
              Text(
                denied
                    ? 'SoloGallery needs access to your library to show your '
                        'photos. Turn it on in Settings — nothing is uploaded, '
                        'ever.'
                    : 'SoloGallery organizes everything right here on this '
                        'device. No cloud, no account, no network — your '
                        'library never leaves your phone.',
                style: text.body.copyWith(color: colors.textSecondary),
              ),
              const SizedBox(height: AppSpace.s32),
              const _Assurance(label: 'LOCAL ONLY', detail: 'Nothing is uploaded or synced'),
              _Assurance(
                label: 'ON DEVICE',
                detail: 'Search and organizing run on your phone',
                color: colors,
              ),
              const _Assurance(
                label: 'NON-DESTRUCTIVE',
                detail: 'Your original photos are never altered',
              ),
              const Spacer(),
              AppButton.primary(
                label: denied ? 'Open Settings' : 'Allow photo access',
                busy: _busy,
                expand: true,
                onPressed: _busy
                    ? null
                    : () => _run(
                          denied
                              ? ref.read(permissionProvider.notifier).openSettings
                              : _requestAccess,
                        ),
              ),
              const SizedBox(height: 14),
              Center(
                child: Text(
                  denied
                      ? 'We\'ll open the library the moment access is on.'
                      : 'You choose what to share — all photos or only some.',
                  textAlign: TextAlign.center,
                  style: text.caption.copyWith(color: colors.textMuted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Step 2: which on-device features to turn on. Deliberately the same
  /// skeleton as step 1 — same eyebrow, headline scale, row rhythm, and pill
  /// CTA — so it reads as the rest of one promise rather than a bolted-on
  /// permission wall. The rows are [_Assurance]'s anatomy with the leading dot
  /// traded for a trailing switch: same voice, but now the user answers.
  Widget _buildConsentStep(BuildContext context) {
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
              Text(
                'SoloGallery',
                style: text.sectionLabel.copyWith(color: colors.textSecondary),
              ),
              // Scrollable rather than Spacer-padded: three switch rows plus
              // the headline overflow a short screen at large font scales, and
              // a RenderFlex overflow is a hard failure on device.
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: AppSpace.s32),
                      Text(
                        'What should stay\non the shelf?',
                        style: text.display.copyWith(color: scheme.onSurface),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'SoloGallery can look through your photos to make them '
                        'easier to find. It all happens on this device — and '
                        'none of it starts until you say so.',
                        style: text.body.copyWith(color: colors.textSecondary),
                      ),
                      const SizedBox(height: AppSpace.s32),
                      _ConsentToggle(
                        label: 'CONTENT SEARCH',
                        detail: 'Find photos by what is in them, and by text '
                            'they contain',
                        value: _search,
                        onChanged: (v) => setState(() => _search = v),
                      ),
                      _ConsentToggle(
                        label: 'MEMORIES',
                        detail: 'Occasional highlights built from photos you '
                            'already have',
                        value: _memories,
                        onChanged: (v) => setState(() => _memories = v),
                      ),
                      _ConsentToggle(
                        label: 'FACE DETECTION',
                        detail: "Groups photos by who's in them. Faces never "
                            'leave this device.',
                        value: _faces,
                        onChanged: (v) => setState(() => _faces = v),
                      ),
                      const SizedBox(height: AppSpace.s8),
                    ],
                  ),
                ),
              ),
              AppButton.primary(
                label: 'Continue',
                busy: _busy,
                expand: true,
                onPressed: _busy ? null : () => _run(_recordConsent),
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
        ),
      ),
    );
  }
}

/// A consent row: [_Assurance]'s tracked-uppercase label over a plain-language
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

/// One quiet promise row: a tracked-out uppercase label over a plain-language
/// detail, led by a small hairline dot (the chrome carries no accent color, so
/// contrast and tracking do the work).
class _Assurance extends StatelessWidget {
  const _Assurance({required this.label, required this.detail, this.color});

  final String label;
  final String detail;
  final AppColors? color;

  @override
  Widget build(BuildContext context) {
    final colors = color ?? Theme.of(context).extension<AppColors>()!;
    final text = Theme.of(context).extension<AppTextStyles>()!;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 5,
            height: 5,
            margin: const EdgeInsets.only(right: 14),
            decoration: BoxDecoration(
              color: colors.textMuted,
              shape: BoxShape.circle,
            ),
          ),
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
        ],
      ),
    );
  }
}
