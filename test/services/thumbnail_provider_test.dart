import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/core/database/app_database.dart';
import 'package:sologallery/core/database/database_provider.dart';
import 'package:sologallery/services/permission_provider.dart';
import 'package:sologallery/services/thumbnail_provider.dart';

import '../support/fake_photo_library_service.dart';

void main() {
  /// A container over an in-memory DB seeded with a photo row ('p') and a
  /// video row ('v'), plus [fake] standing in for the platform round-trip —
  /// `videoDurationCalls` on the fake proves whether it was reached at all.
  Future<ProviderContainer> containerWith(FakePhotoLibraryService fake) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.indexDao.upsertMetadata([
      (
        id: 'p',
        createdAt: DateTime(2026, 1, 1),
        isVideo: false,
        width: 100,
        height: 100,
        isDated: true,
      ),
      (
        id: 'v',
        createdAt: DateTime(2026, 1, 1),
        isVideo: true,
        width: 100,
        height: 100,
        isDated: true,
      ),
    ]);
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        photoLibraryServiceProvider.overrideWithValue(fake),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test(
    'a non-video resolves to null without calling PhotoLibraryService.videoDuration',
    () async {
      final fake = FakePhotoLibraryService();
      final container = await containerWith(fake);

      final duration = await container.read(videoDurationProvider('p').future);

      expect(duration, isNull);
      expect(fake.videoDurationCalls, isEmpty);
    },
  );

  test(
    'an id not yet in the cache also resolves to null without the round-trip',
    () async {
      final fake = FakePhotoLibraryService();
      final container = await containerWith(fake);

      final duration = await container.read(
        videoDurationProvider('unknown').future,
      );

      expect(duration, isNull);
      expect(fake.videoDurationCalls, isEmpty);
    },
  );

  test('a video calls through to PhotoLibraryService.videoDuration', () async {
    final fake = FakePhotoLibraryService(
      videoDurations: {'v': const Duration(minutes: 1, seconds: 5)},
    );
    final container = await containerWith(fake);

    final duration = await container.read(videoDurationProvider('v').future);

    expect(duration, const Duration(minutes: 1, seconds: 5));
    expect(fake.videoDurationCalls, ['v']);
  });
}
