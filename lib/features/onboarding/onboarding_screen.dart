import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/permission_provider.dart';
import '../settings/consent_provider.dart';
import '../settings/widgets/folder_picker_sheet.dart';
import 'widgets/access_step.dart';
import 'widgets/consent_step.dart';

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

  /// Folder ids excluded from on-device analysis. Empty means every folder is
  /// included, which is the default until the user opens the picker.
  Set<String> _excludedFolderIds = const {};

  Future<void> _requestAccess() async {
    await ref.read(permissionProvider.notifier).request();
    if (mounted) setState(() => _attempted = true);
  }

  Future<void> _recordConsent() {
    return ref
        .read(consentProvider.notifier)
        .record(
          search: _search,
          memories: _memories,
          faces: _faces,
          excludedFolderIds: _excludedFolderIds,
        );
  }

  Future<void> _openFolderPicker() async {
    final result = await FolderPickerSheet.show(
      context,
      initialExcluded: _excludedFolderIds,
    );
    if (result != null && mounted) {
      setState(() => _excludedFolderIds = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final access = ref.watch(permissionProvider);
    final showConsent =
        access.canReadLibrary &&
        ref.watch(consentProvider) == ConsentState.needed;
    // A hard cut between the two steps. Keying by step means arriving at a
    // step always mounts it fresh every time — including the second time
    // consent is reached after access is revoked and re-granted — so each
    // step's state resets rather than carrying over.
    return KeyedSubtree(
      key: ValueKey(showConsent ? 'consent' : 'access'),
      child: showConsent
          ? ConsentStep(
              busy: _busy,
              search: _search,
              memories: _memories,
              faces: _faces,
              excludedFolderIds: _excludedFolderIds,
              onSearchChanged: (v) => setState(() => _search = v),
              onMemoriesChanged: (v) => setState(() => _memories = v),
              onFacesChanged: (v) => setState(() => _faces = v),
              onOpenFolderPicker: _openFolderPicker,
              onContinue: () => _run(_recordConsent),
            )
          : AccessStep(
              access: access,
              attempted: _attempted,
              busy: _busy,
              onRequestAccess: () => _run(_requestAccess),
              onOpenSettings: () =>
                  _run(ref.read(permissionProvider.notifier).openSettings),
            ),
    );
  }
}
