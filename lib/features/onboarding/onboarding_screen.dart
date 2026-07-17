import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../services/permission_provider.dart';
import '../../services/photo_library_service.dart';

/// First-run gate. The router sends the user here whenever the app lacks
/// library access (see `app_router.dart` redirect). It leads with the app's
/// one promise — photos never leave the device — then asks for access. When
/// access is granted the redirect moves the user on to the Library.
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

  Future<void> _requestAccess() async {
    await ref.read(permissionProvider.notifier).request();
    if (mounted) setState(() => _attempted = true);
  }

  @override
  Widget build(BuildContext context) {
    final access = ref.watch(permissionProvider);
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
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 20),
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
                style: TextStyle(
                  fontSize: 34,
                  height: 1.08,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                  color: scheme.onSurface,
                ),
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
              const SizedBox(height: 32),
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
              _PrimaryButton(
                label: denied ? 'Open Settings' : 'Allow photo access',
                busy: _busy,
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
      padding: const EdgeInsets.only(bottom: 16),
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

/// The one high-contrast element on the screen: an inverted pill CTA.
class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: Material(
        color: colors.pillActiveBg,
        borderRadius: BorderRadius.circular(26),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Center(
            child: busy
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.pillActiveText,
                    ),
                  )
                : Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: colors.pillActiveText,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
