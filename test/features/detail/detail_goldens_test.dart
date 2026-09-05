import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sologallery/core/database/app_database.dart' show Album;
import 'package:sologallery/core/theme/app_theme.dart';
import 'package:sologallery/features/detail/detail_providers.dart';
import 'package:sologallery/features/detail/widgets/add_to_album_sheet.dart';
import 'package:sologallery/features/detail/widgets/detail_action_bar.dart';
import 'package:sologallery/features/detail/widgets/exif_sheet.dart';
import 'package:sologallery/services/photo_library_service.dart';

void main() {
  /// Themed light+dark scenarios on each theme's own surface.
  GoldenTestGroup themedGroup(Widget Function(ThemeData) build) {
    return GoldenTestGroup(
      columns: 1,
      children: [
        for (final e in {'light': AppTheme.light, 'dark': AppTheme.dark}.entries)
          GoldenTestScenario(
            name: e.key,
            child: Theme(
              data: e.value,
              child: Material(
                color: e.value.scaffoldBackgroundColor,
                child: SizedBox(width: 360, child: build(e.value)),
              ),
            ),
          ),
      ],
    );
  }

  goldenTest(
    'DetailActionBar — favorited and not, over black',
    fileName: 'detail_action_bar',
    builder: () => GoldenTestGroup(
      columns: 1,
      children: [
        for (final fav in [false, true])
          GoldenTestScenario(
            name: fav ? 'favorited' : 'default',
            child: ColoredBox(
              color: Colors.black,
              child: SizedBox(
                width: 360,
                child: DetailActionBar(
                  isFavorite: fav,
                  onFavorite: () {},
                  onInfo: () {},
                  onDelete: () {},
                ),
              ),
            ),
          ),
      ],
    ),
  );

  goldenTest(
    'ExifSheet — populated metadata',
    fileName: 'exif_sheet',
    builder: () => themedGroup(
      (_) => ProviderScope(
        overrides: [
          isFavoriteProvider('x').overrideWith((ref) => Stream.value(false)),
          assetDetailProvider('x').overrideWith((ref) => AssetDetail(
                id: 'x',
                width: 6048,
                height: 8064,
                createdAt: DateTime(2026, 7, 12, 14, 33),
                orientationDegrees: 0,
                isVideo: false,
                sizeBytes: 2202009,
                mimeType: 'image/heic',
                latitude: 37.7749,
                longitude: -122.4194,
              )),
        ],
        child: const ExifSheet(assetId: 'x'),
      ),
    ),
  );

  goldenTest(
    'ExifSheet — no EXIF data',
    fileName: 'exif_sheet_no_exif',
    builder: () => themedGroup(
      (_) => ProviderScope(
        overrides: [
          isFavoriteProvider('x').overrideWith((ref) => Stream.value(false)),
          assetDetailProvider('x').overrideWith((ref) => AssetDetail(
                id: 'x',
                width: 800,
                height: 600,
                createdAt: DateTime(2026, 3, 1, 9, 5),
                orientationDegrees: 0,
                isVideo: false,
              )),
        ],
        child: const ExifSheet(assetId: 'x'),
      ),
    ),
  );

  goldenTest(
    'ExifSheet — long location value',
    fileName: 'exif_sheet_long_location',
    builder: () => themedGroup(
      (_) => ProviderScope(
        overrides: [
          isFavoriteProvider('x').overrideWith((ref) => Stream.value(false)),
          assetDetailProvider('x').overrideWith((ref) => AssetDetail(
                id: 'x',
                width: 6048,
                height: 8064,
                createdAt: DateTime(2026, 7, 12, 14, 33),
                orientationDegrees: 0,
                isVideo: false,
                // Deliberately out-of-range magnitude — stresses the fixed
                // value column's wrap behaviour; not a real coordinate.
                latitude: 123456789.1234,
                longitude: -987654321.5678,
              )),
        ],
        child: const ExifSheet(assetId: 'x'),
      ),
    ),
  );

  goldenTest(
    'AddToAlbumSheet — with albums',
    fileName: 'add_to_album_sheet',
    builder: () => themedGroup(
      (_) => ProviderScope(
        overrides: [
          albumsListProvider.overrideWith(
            (ref) => Stream.value([
              Album(
                id: 1,
                name: 'Iceland',
                coverAssetId: null,
                createdAt: DateTime(2026, 1, 1),
                sortIndex: 0,
              ),
              Album(
                id: 2,
                name: 'Family',
                coverAssetId: null,
                createdAt: DateTime(2026, 2, 1),
                sortIndex: 1,
              ),
            ]),
          ),
        ],
        // Bound the height so the sheet's Flexible list lays out in isolation.
        child: const SizedBox(height: 320, child: AddToAlbumSheet(assetId: 'x')),
      ),
    ),
  );
}
