import 'package:flutter_test/flutter_test.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:sologallery/services/photo_library_service.dart';

void main() {
  group('PhotoLibraryService.accessFromState', () {
    test('maps every PermissionState to a PhotoAccess', () {
      expect(PhotoLibraryService.accessFromState(PermissionState.authorized),
          PhotoAccess.granted);
      expect(PhotoLibraryService.accessFromState(PermissionState.limited),
          PhotoAccess.limited);
      expect(PhotoLibraryService.accessFromState(PermissionState.notDetermined),
          PhotoAccess.notDetermined);
      expect(PhotoLibraryService.accessFromState(PermissionState.denied),
          PhotoAccess.denied);
      expect(PhotoLibraryService.accessFromState(PermissionState.restricted),
          PhotoAccess.denied);
    });

    test('canReadLibrary only for granted and limited', () {
      expect(PhotoAccess.granted.canReadLibrary, isTrue);
      expect(PhotoAccess.limited.canReadLibrary, isTrue);
      expect(PhotoAccess.denied.canReadLibrary, isFalse);
      expect(PhotoAccess.notDetermined.canReadLibrary, isFalse);
    });
  });
}
