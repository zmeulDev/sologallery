import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/core/theme/app_theme.dart';
import 'package:sologallery/features/detail/detail_providers.dart';
import 'package:sologallery/features/detail/widgets/exif_sheet.dart';
import 'package:sologallery/services/photo_library_service.dart';

/// Behavioural coverage for the EXIF sheet's chip selection over the two
/// interesting metadata shapes — a full record with GPS, and a record with
/// every optional field absent.
///
/// The `gps_exif.jpg` / `no_exif.jpg` fixtures were made for these two shapes,
/// but the app only ever reads a JPEG's EXIF through `photo_manager` on a
/// device (`entity.latlngAsync()`, `entity.mimeTypeAsync`); there is no
/// host-side EXIF reader in `lib/`. `asset_detail_display.dart` — the formatter
/// this sheet lays out — is pure primitive formatting and already fully unit
/// tested. So the untested surface is `_Chips`: which chips render for which
/// `AssetDetail`. This is that test, driven by the same shapes the fixtures
/// carry rather than by the fixtures themselves.
void main() {
  Future<void> pumpSheet(WidgetTester tester, AssetDetail? detail) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          assetDetailProvider('x').overrideWith((ref) => detail),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: ExifSheet(assetId: 'x')),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  // A still image with every optional field the sheet knows how to show, GPS
  // included — tagged at the same Zurich coordinates as `gps_exif.jpg`.
  AssetDetail fullRecord() => AssetDetail(
        id: 'x',
        width: 8000,
        height: 6000,
        createdAt: DateTime(2026, 7, 12, 14, 33),
        orientationDegrees: 0,
        isVideo: false,
        sizeBytes: 2202009,
        mimeType: 'image/jpeg',
        latitude: 47.3764,
        longitude: 8.5476,
      );

  // Only the fields `photo_manager` always provides; every optional one null —
  // the shape a `no_exif.jpg`-style asset degrades to.
  AssetDetail emptyRecord() => AssetDetail(
        id: 'x',
        width: 800,
        height: 600,
        createdAt: DateTime(2026, 3, 1, 9, 5),
        orientationDegrees: 0,
        isVideo: false,
      );

  testWidgets('full record renders every chip with formatted values', (
    tester,
  ) async {
    await pumpSheet(tester, fullRecord());

    expect(find.text('DETAILS'), findsOneWidget);
    expect(find.text('Jul 12, 2026 · 14:33'), findsOneWidget); // Taken
    expect(find.text('8000 × 6000'), findsOneWidget); // Dimensions
    expect(find.text('48.0 MP'), findsOneWidget); // Resolution
    expect(find.text('2.1 MB'), findsOneWidget); // Size
    expect(find.text('JPEG'), findsOneWidget); // Type
    expect(find.text('LOCATION'), findsOneWidget);
    expect(find.text('47.3764, 8.5476'), findsOneWidget); // Location
  });

  testWidgets('empty record degrades to the always-present chips, no blanks', (
    tester,
  ) async {
    await pumpSheet(tester, emptyRecord());

    // The chips that need only always-present fields still render.
    expect(find.text('Mar 1, 2026 · 09:05'), findsOneWidget);
    expect(find.text('800 × 600'), findsOneWidget);
    expect(find.text('0.5 MP'), findsOneWidget);

    // The optional chips are absent entirely — not shown with an empty value.
    expect(find.text('DURATION'), findsNothing);
    expect(find.text('SIZE'), findsNothing);
    expect(find.text('TYPE'), findsNothing);
    expect(find.text('LOCATION'), findsNothing);

    // No empty-string value leaked into a rendered chip.
    expect(
      find.byWidgetPredicate((w) => w is Text && w.data == ''),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a null projection shows the unavailable note, not a broken sheet',
      (tester) async {
    await pumpSheet(tester, null);

    expect(
      find.text("Details aren't available for this photo."),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
