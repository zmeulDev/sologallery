import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/core/database/daos/albums_dao.dart'
    show AlbumSummary;
import 'package:sologallery/core/theme/app_theme.dart';
import 'package:sologallery/features/search/widgets/albums_result.dart';

void main() {
  testWidgets('the album name is bold', (tester) async {
    const summary = AlbumSummary(
      id: 1,
      name: 'Trip',
      entryCount: 3,
      coverAssetId: null,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: AlbumsResult(albums: [summary])),
      ),
    );
    await tester.pump();

    expect(
      tester.widget<Text>(find.text('Trip')).style?.fontWeight,
      FontWeight.w700,
    );
  });
}
