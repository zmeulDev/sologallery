import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import 'photo_library_service.dart';

final _log = Logger('SoloGallery.photos');

/// App-wide [PhotoLibraryService], kept alive for the app's lifetime (it owns no
/// heavy resources but is the single plugin entry point). Overridden with a fake
/// in tests.
final photoLibraryServiceProvider = Provider<PhotoLibraryService>((ref) {
  return PhotoLibraryService();
});

/// Current photo-library [PhotoAccess], kept alive app-wide. The router's
/// redirect reads this synchronously to gate the onboarding screen, and the
/// Library screen reacts to it (limited-access banner, empty states).
///
/// On construction it seeds [PhotoAccess.notDetermined] — which routes to
/// onboarding, the correct destination while access is still unknown — then
/// asynchronously reads the real state. [refresh] is also called on app resume
/// (see `app.dart`) to catch access revoked in system settings mid-session.
class PermissionNotifier extends Notifier<PhotoAccess> {
  @override
  PhotoAccess build() {
    // Fire-and-forget the real read; `state` updates when it resolves.
    Future.microtask(refresh);
    return PhotoAccess.notDetermined;
  }

  PhotoLibraryService get _service => ref.read(photoLibraryServiceProvider);

  /// Re-reads the current access without prompting.
  Future<void> refresh() async {
    final access = await _service.currentAccess();
    if (access != state) {
      _log.info('Photo access changed: $state -> $access');
    }
    state = access;
  }

  /// Prompts for access (native dialog) and stores the result.
  Future<void> request() async {
    state = await _service.requestAccess();
  }

  /// Opens system settings so the user can change a denied grant.
  Future<void> openSettings() => _service.openSettings();

  /// Re-presents the limited-access picker, then re-reads access (the granted
  /// subset may have changed).
  Future<void> presentLimited() async {
    await _service.presentLimited();
    await refresh();
  }
}

final permissionProvider = NotifierProvider<PermissionNotifier, PhotoAccess>(
  PermissionNotifier.new,
);
