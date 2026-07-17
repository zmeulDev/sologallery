import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/features/library/domain/year_month.dart';
import 'package:sologallery/features/library/month_assets_provider.dart';
import 'package:sologallery/services/permission_provider.dart';
import 'package:sologallery/services/photo_library_service.dart';

import '../../support/asset_fixtures.dart';
import '../../support/fake_photo_library_service.dart';

void main() {
  const month = YearMonth(2026, 7);

  ProviderContainer containerWith(List<AssetRef> assets) {
    final fake = FakePhotoLibraryService(
      access: PhotoAccess.granted,
      assets: assets,
    );
    final container = ProviderContainer(
      overrides: [photoLibraryServiceProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('first page is capped at the page size with more available', () async {
    final container = containerWith(assetsInMonth(2026, 7, 200));
    final first = await container.read(monthAssetsProvider(month).future);

    expect(first, hasLength(90)); // PagedAssetsNotifier.pageSize
    expect(container.read(monthAssetsProvider(month).notifier).hasMore, isTrue);
  });

  test('loadMore appends pages until exhausted', () async {
    final container = containerWith(assetsInMonth(2026, 7, 200));
    await container.read(monthAssetsProvider(month).future);
    final notifier = container.read(monthAssetsProvider(month).notifier);

    await notifier.loadMore();
    expect(container.read(monthAssetsProvider(month)).value, hasLength(180));
    expect(notifier.hasMore, isTrue);

    await notifier.loadMore(); // final partial page (20)
    expect(container.read(monthAssetsProvider(month)).value, hasLength(200));
    expect(notifier.hasMore, isFalse);

    await notifier.loadMore(); // no-op once exhausted
    expect(container.read(monthAssetsProvider(month)).value, hasLength(200));
  });

  test('short month reports no more after the first page', () async {
    final container = containerWith(assetsInMonth(2026, 7, 5));
    final first = await container.read(monthAssetsProvider(month).future);

    expect(first, hasLength(5));
    expect(container.read(monthAssetsProvider(month).notifier).hasMore, isFalse);
  });
}
