import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/core/database/app_database.dart';
import 'package:sologallery/core/database/database_provider.dart';
import 'package:sologallery/features/library/domain/year_month.dart';
import 'package:sologallery/features/library/library_providers.dart';
import 'package:sologallery/services/permission_provider.dart';
import 'package:sologallery/services/photo_library_service.dart';

import '../../support/asset_fixtures.dart';
import '../../support/fake_photo_library_service.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  /// Caches [assets] as dated (or undated) rows, mirroring the metadata sweep.
  Future<void> cache(List<AssetRef> assets, {bool dated = true}) {
    return db.indexDao.upsertMetadata([
      for (final a in assets)
        (
          id: a.id,
          createdAt: a.createdAt,
          isVideo: false,
          width: 1,
          height: 1,
          isDated: dated,
        ),
    ]);
  }

  /// A container backed by the in-memory DB, with the given photo access.
  Future<ProviderContainer> containerWith({
    PhotoAccess access = PhotoAccess.granted,
  }) async {
    final fake = FakePhotoLibraryService(access: access);
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        photoLibraryServiceProvider.overrideWithValue(fake),
      ],
    );
    addTearDown(container.dispose);
    await container.read(permissionProvider.notifier).refresh();
    return container;
  }

  /// Polls [provider] (a real-async Drift/Future provider) until it holds data.
  Future<T> readData<T>(
    ProviderContainer container,
    ProviderListenable<AsyncValue<T>> provider,
  ) async {
    container.listen(provider, (_, _) {});
    for (var i = 0; i < 100; i++) {
      final value = container.read(provider);
      if (value.hasValue) return value.value as T;
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    throw StateError('provider never produced a value');
  }

  test('month counts are empty without library access', () async {
    final container = await containerWith(access: PhotoAccess.denied);
    await cache(assetsInMonth(2026, 8, 3));
    expect(await readData(container, libraryMonthCountsProvider), isEmpty);
  });

  test('groups cached dated assets into month counts, newest first', () async {
    final container = await containerWith();
    await cache([
      ...assetsInMonth(2026, 8, 7),
      ...assetsInMonth(2026, 6, 2),
      ...assetsInMonth(2026, 5, 1),
    ]);

    final counts = await readData(container, libraryMonthCountsProvider);
    expect(counts.map((e) => e.month).toList(),
        const [YearMonth(2026, 8), YearMonth(2026, 6), YearMonth(2026, 5)]);
    expect(counts.map((e) => e.count).toList(), [7, 2, 1]);
  });

  test('monthPreviews caps at six newest ids', () async {
    final container = await containerWith();
    await cache(assetsInMonth(2026, 8, 7));

    final previews =
        await readData(container, monthPreviewsProvider(const YearMonth(2026, 8)));
    expect(previews, hasLength(6));
  });

  test('older count and previews cover undated assets', () async {
    final container = await containerWith();
    await cache(assetsInMonth(2026, 8, 3));
    await cache(assetsInMonth(2020, 1, 9, prefix: 'u'), dated: false);

    expect(await readData(container, olderCountProvider), 9);
    expect(await readData(container, olderPreviewsProvider), hasLength(6));
    // Undated assets never leak into the month counts.
    final counts = await readData(container, libraryMonthCountsProvider);
    expect(counts.map((e) => e.month).toList(), const [YearMonth(2026, 8)]);
  });

  test('older count is zero without undated assets', () async {
    final container = await containerWith();
    await cache(assetsInMonth(2026, 8, 3));
    expect(await readData(container, olderCountProvider), 0);
  });

  test('older count is zero without library access', () async {
    final container = await containerWith(access: PhotoAccess.denied);
    await cache(assetsInMonth(2020, 1, 4, prefix: 'u'), dated: false);
    expect(await readData(container, olderCountProvider), 0);
  });

  test('this week day counts are empty without library access', () async {
    final container = await containerWith(access: PhotoAccess.denied);
    await cache(assetsInMonth(2026, 8, 3));
    expect(await readData(container, thisWeekDayCountsProvider), isEmpty);
  });

  test('this week groups dated assets into day counts, newest first', () async {
    final container = await containerWith();
    // `thisWeekDayCountsProvider` is a rolling last-7-days window resolved
    // against the real clock, so the seeded days have to be the real today and
    // yesterday — hard-coded dates pass on the day they are written and fail
    // once they age out of the window.
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    await cache([
      AssetRef(id: 'today-1', createdAt: today),
      AssetRef(id: 'today-2', createdAt: today.add(const Duration(seconds: 1))),
      AssetRef(id: 'today-3', createdAt: today.add(const Duration(seconds: 2))),
      AssetRef(id: 'yesterday-1', createdAt: yesterday),
      AssetRef(
          id: 'yesterday-2',
          createdAt: yesterday.add(const Duration(seconds: 1))),
    ]);

    final counts = await readData(container, thisWeekDayCountsProvider);
    expect(counts.map((e) => e.day).toList(), [today, yesterday]);
    expect(counts.map((e) => e.count).toList(), [3, 2]);
  });

  test('dayPreviews caps at six newest ids', () async {
    final container = await containerWith();
    await cache(assetsInMonth(2026, 8, 7));

    final previews =
        await readData(container, dayPreviewsProvider(DateTime(2026, 8, 28)));
    expect(previews, hasLength(6));
  });
}
