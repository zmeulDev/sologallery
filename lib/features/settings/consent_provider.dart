import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../../core/database/database_provider.dart';
import '../../services/indexing_service.dart';

final _log = Logger('SoloGallery.db');

/// Whether the user has been asked about on-device analysis yet.
enum ConsentState {
  /// The stored answer hasn't been read back yet. Deliberately *not* a redirect
  /// trigger — see [ConsentNotifier].
  unresolved,

  /// Never asked: onboarding must show the consent step.
  needed,

  /// Answered (either way). The two feature flags carry the actual answers.
  recorded,
}

/// Whether the on-device analysis consent prompt has been answered, kept alive
/// app-wide.
///
/// This is a [Notifier] rather than a `StreamProvider` because the router's
/// `redirect` reads it **synchronously** — the same reason
/// [PermissionNotifier] exists in its shape.
///
/// Unlike photo access, the initial [ConsentState.unresolved] does *not* route
/// to onboarding. Holding there while the Drift read resolves would flash the
/// consent step at every existing user on cold start; the step is only reachable
/// right after the user grants photo access, by which point this has long
/// resolved. Erring toward "don't interrupt" is safe here — no analysis runs
/// until the flags say so regardless.
class ConsentNotifier extends Notifier<ConsentState> {
  @override
  ConsentState build() {
    Future.microtask(refresh);
    return ConsentState.unresolved;
  }

  /// Re-reads the stored consent record.
  Future<void> refresh() async {
    final recorded = await ref.read(settingsDaoProvider).readConsentRecorded();
    state = recorded ? ConsentState.recorded : ConsentState.needed;
  }

  /// Records the user's answers to the consent prompt and marks it answered, so
  /// declining everything doesn't re-prompt on every launch.
  ///
  /// Routed through [IndexingService] rather than writing the flags directly:
  /// an **upgrading** user reaches this step with labels, faces, persons, and
  /// memories already derived from before consent existed, so declining has to
  /// delete them. Writing the settings straight to the DAO would leave exactly
  /// the data the user just refused sitting on disk.
  ///
  /// All three answers go through a single [IndexingService.applyConsent] —
  /// setting them one at a time let an indexing pass start on a half-written
  /// answer (see that method).
  Future<void> record({
    required bool search,
    required bool memories,
    required bool faces,
  }) async {
    await ref.read(indexingServiceProvider).applyConsent(
          searchEnabled: search,
          memoriesEnabled: memories,
          facesEnabled: faces,
        );
    _log.info(
      'Analysis consent recorded '
      '(search: $search, memories: $memories, faces: $faces)',
    );
    state = ConsentState.recorded;
  }
}

final consentProvider = NotifierProvider<ConsentNotifier, ConsentState>(
  ConsentNotifier.new,
);

/// Whether content search (ML labels + OCR) is enabled. App-wide and kept
/// alive — the Search screen and the Settings screen both read it.
final searchEnabledProvider = StreamProvider<bool>((ref) {
  return ref.watch(settingsDaoProvider).watchSearchEnabled();
});

/// Whether auto-curated Memories are enabled. App-wide and kept alive — the
/// Library carousel and the Settings screen both read it.
final memoriesEnabledProvider = StreamProvider<bool>((ref) {
  return ref.watch(settingsDaoProvider).watchMemoriesEnabled();
});

/// Whether face detection / People is enabled. App-wide and kept alive — Search,
/// the People screens, and Settings all read it.
final facesEnabledProvider = StreamProvider<bool>((ref) {
  return ref.watch(settingsDaoProvider).watchFacesEnabled();
});
