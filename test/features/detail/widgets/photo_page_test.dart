import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/features/detail/detail_providers.dart';
import 'package:sologallery/features/detail/widgets/photo_page.dart';

Uint8List _loadBytes(String name) =>
    File('test_assets/$name').readAsBytesSync();

void main() {
  testWidgets('shows the grid placeholder instantly, then swaps to high-res', (
    tester,
  ) async {
    final placeholder = _loadBytes('small_png.png');
    final highRes = _loadBytes('synthetic_face.jpg');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          detailImageProvider.overrideWith((ref, id) async {
            await Future.delayed(const Duration(milliseconds: 100));
            return highRes;
          }),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: PhotoPage(
              assetId: 'a1',
              placeholderBytes: placeholder,
            ),
          ),
        ),
      ),
    );

    await tester.pump();

    final firstImage = tester.widget<Image>(find.byType(Image));
    expect((firstImage.image as MemoryImage).bytes, placeholder);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();

    final secondImage = tester.widget<Image>(find.byType(Image));
    expect((secondImage.image as MemoryImage).bytes, highRes);
  });

  testWidgets('falls back to spinner when no placeholder and high-res loads', (
    tester,
  ) async {
    final highRes = _loadBytes('synthetic_face.jpg');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          detailImageProvider.overrideWith((ref, id) async {
            await Future.delayed(const Duration(milliseconds: 100));
            return highRes;
          }),
        ],
        child: const MaterialApp(
          home: Scaffold(body: PhotoPage(assetId: 'a1')),
        ),
      ),
    );

    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as MemoryImage).bytes, highRes);
  });
}
