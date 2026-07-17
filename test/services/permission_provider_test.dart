import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/services/permission_provider.dart';
import 'package:sologallery/services/photo_library_service.dart';

import '../support/fake_photo_library_service.dart';

void main() {
  ProviderContainer containerWith(FakePhotoLibraryService fake) {
    final container = ProviderContainer(
      overrides: [photoLibraryServiceProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('seeds notDetermined then reads the real access on build', () async {
    final fake = FakePhotoLibraryService(access: PhotoAccess.limited);
    final container = containerWith(fake);

    expect(container.read(permissionProvider), PhotoAccess.notDetermined);
    await container.read(permissionProvider.notifier).refresh();
    expect(container.read(permissionProvider), PhotoAccess.limited);
  });

  test('request transitions to the grant result', () async {
    final fake = FakePhotoLibraryService(
      access: PhotoAccess.denied,
      grantResult: PhotoAccess.granted,
    );
    final container = containerWith(fake);
    container.read(permissionProvider); // build

    await container.read(permissionProvider.notifier).request();

    expect(container.read(permissionProvider), PhotoAccess.granted);
    expect(fake.requestCount, 1);
  });

  test('request that stays denied keeps denied', () async {
    final fake = FakePhotoLibraryService(access: PhotoAccess.denied);
    final container = containerWith(fake);
    container.read(permissionProvider);

    await container.read(permissionProvider.notifier).request();

    expect(container.read(permissionProvider), PhotoAccess.denied);
  });

  test('presentLimited re-presents the picker and refreshes', () async {
    final fake = FakePhotoLibraryService(access: PhotoAccess.limited);
    final container = containerWith(fake);
    container.read(permissionProvider);

    await container.read(permissionProvider.notifier).presentLimited();

    expect(fake.presentLimitedCount, 1);
    expect(container.read(permissionProvider), PhotoAccess.limited);
  });

  test('openSettings delegates to the service', () async {
    final fake = FakePhotoLibraryService(access: PhotoAccess.denied);
    final container = containerWith(fake);
    container.read(permissionProvider);

    await container.read(permissionProvider.notifier).openSettings();

    expect(fake.openSettingsCount, 1);
  });
}
