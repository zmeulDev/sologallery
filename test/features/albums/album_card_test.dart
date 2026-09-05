import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/core/database/daos/albums_dao.dart'
    show AlbumSummary;
import 'package:sologallery/core/format/count_labels.dart';
import 'package:sologallery/core/theme/app_theme.dart';
import 'package:sologallery/features/albums/widgets/album_card.dart';
import 'package:sologallery/services/permission_provider.dart';
import 'package:sologallery/widgets/app_card.dart';
import 'package:sologallery/widgets/asset_thumbnail.dart';

import '../../support/fake_photo_library_service.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required AlbumSummary summary,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
  }) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: [
          photoLibraryServiceProvider.overrideWithValue(
            FakePhotoLibraryService(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: AlbumCard(
            summary: summary,
            onTap: onTap,
            onLongPress: onLongPress,
          ),
        ),
      ),
    );
  }

  testWidgets('shows album name and photo count', (tester) async {
    const summary = AlbumSummary(
      id: 1,
      name: 'Trip',
      entryCount: 3,
      coverAssetId: 'c1',
    );
    await pump(tester, summary: summary);
    await tester.pump();

    expect(find.text('Trip'), findsOneWidget);
    expect(find.text(photoCountLabel(3)), findsOneWidget);
    expect(find.byType(AppCard), findsOneWidget);
    expect(find.byType(AssetThumbnail), findsOneWidget);
  });

  testWidgets('the album name is bold', (tester) async {
    const summary = AlbumSummary(
      id: 4,
      name: 'Trip',
      entryCount: 3,
      coverAssetId: 'c1',
    );
    await pump(tester, summary: summary);
    await tester.pump();

    expect(
      tester.widget<Text>(find.text('Trip')).style?.fontWeight,
      FontWeight.w700,
    );
  });

  testWidgets('empty album shows placeholder cover and Empty caption', (
    tester,
  ) async {
    const summary = AlbumSummary(
      id: 2,
      name: 'Empty album',
      entryCount: 0,
      coverAssetId: null,
    );
    await pump(tester, summary: summary);
    await tester.pump();

    expect(find.text('Empty album'), findsOneWidget);
    expect(find.text('Empty'), findsOneWidget);
    expect(find.byType(AssetThumbnail), findsNothing);
    expect(find.byIcon(Icons.photo_album_outlined), findsOneWidget);
  });

  testWidgets('tap and long-press callbacks fire', (tester) async {
    var tapped = false;
    var longPressed = false;
    const summary = AlbumSummary(
      id: 3,
      name: 'Events',
      entryCount: 1,
      coverAssetId: null,
    );
    await pump(
      tester,
      summary: summary,
      onTap: () => tapped = true,
      onLongPress: () => longPressed = true,
    );
    await tester.pump();

    await tester.tap(find.text('Events'));
    expect(tapped, isTrue);

    await tester.longPress(find.text('Events'));
    expect(longPressed, isTrue);
  });
}
