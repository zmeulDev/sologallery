import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/features/library/domain/year_month.dart';
import 'package:sologallery/features/library/library_providers.dart';
import 'package:sologallery/services/permission_provider.dart';
import 'package:sologallery/services/photo_library_service.dart';

import '../../support/asset_fixtures.dart';
import '../../support/fake_photo_library_service.dart';

void main() {
  /// Builds a container with granted access and the given library, keeping the
  /// month provider alive and returning it after the first load resolves.
  Future<(ProviderContainer, List<dynamic>)> loadedLibrary(
    List<AssetRef> assets,
  ) async {
    final fake = FakePhotoLibraryService(
      access: PhotoAccess.granted,
      assets: assets,
    );
    final container = ProviderContainer(
      overrides: [photoLibraryServiceProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);
    container.listen(libraryMonthsProvider, (_, _) {});
    await container.read(permissionProvider.notifier).refresh();
    final months = await container.read(libraryMonthsProvider.future);
    return (container, months);
  }

  test('is empty and idle without library access', () async {
    final fake = FakePhotoLibraryService(access: PhotoAccess.denied);
    final container = ProviderContainer(
      overrides: [photoLibraryServiceProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);
    container.listen(libraryMonthsProvider, (_, _) {});
    await container.read(permissionProvider.notifier).refresh();

    expect(await container.read(libraryMonthsProvider.future), isEmpty);
  });

  test('empty library yields no sections', () async {
    final (_, months) = await loadedLibrary(const []);
    expect(months, isEmpty);
  });

  test('builds month summaries with counts and capped previews', () async {
    final (_, months) = await loadedLibrary(assetsInMonth(2026, 8, 7));
    expect(months, hasLength(1));
    final summary = months.single;
    expect(summary.month, const YearMonth(2026, 8));
    expect(summary.count, 7);
    expect(summary.previewAssetIds, hasLength(6)); // capped at six
  });

  test('olderSummaryProvider is null without undated photos', () async {
    final fake = FakePhotoLibraryService(
      access: PhotoAccess.granted,
      assets: assetsInMonth(2026, 8, 3),
    );
    final container = ProviderContainer(
      overrides: [photoLibraryServiceProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);
    await container.read(permissionProvider.notifier).refresh();
    expect(await container.read(olderSummaryProvider.future), isNull);
  });

  test('olderSummaryProvider summarizes undated photos', () async {
    final fake = FakePhotoLibraryService(
      access: PhotoAccess.granted,
      assets: assetsInMonth(2026, 8, 3),
      undatedAssets: assetsInMonth(2020, 1, 9, prefix: 'u'),
    );
    final container = ProviderContainer(
      overrides: [photoLibraryServiceProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);
    await container.read(permissionProvider.notifier).refresh();

    final older = await container.read(olderSummaryProvider.future);
    expect(older, isNotNull);
    expect(older!.count, 9);
    expect(older.previewAssetIds, hasLength(6)); // capped at six
  });

  test('olderSummaryProvider is null without library access', () async {
    final fake = FakePhotoLibraryService(
      access: PhotoAccess.denied,
      undatedAssets: assetsInMonth(2020, 1, 4),
    );
    final container = ProviderContainer(
      overrides: [photoLibraryServiceProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);
    await container.read(permissionProvider.notifier).refresh();
    expect(await container.read(olderSummaryProvider.future), isNull);
  });

  test('lazily reveals months in batches, skipping empty months', () async {
    // Non-empty: 08, 06, 05, 04, 03, 02 (07 is an intentional gap).
    final assets = <AssetRef>[
      ...assetsInMonth(2026, 8, 7),
      ...assetsInMonth(2026, 6, 1),
      ...assetsInMonth(2026, 5, 1),
      ...assetsInMonth(2026, 4, 1),
      ...assetsInMonth(2026, 3, 1),
      ...assetsInMonth(2026, 2, 1),
    ];
    final (container, first) = await loadedLibrary(assets);
    final notifier = container.read(libraryMonthsProvider.notifier);

    // First batch is four non-empty months; the 07 gap never appears.
    expect(first.map((m) => m.month).toList(), const [
      YearMonth(2026, 8),
      YearMonth(2026, 6),
      YearMonth(2026, 5),
      YearMonth(2026, 4),
    ]);
    expect(notifier.hasMore, isTrue);

    await notifier.loadMore();
    final all = container.read(libraryMonthsProvider).value!;
    expect(all.map((m) => m.month).toList(), const [
      YearMonth(2026, 8),
      YearMonth(2026, 6),
      YearMonth(2026, 5),
      YearMonth(2026, 4),
      YearMonth(2026, 3),
      YearMonth(2026, 2),
    ]);
    expect(notifier.hasMore, isFalse);
  });
}
