import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/core/database/daos/memories_dao.dart'
    show MemorySummary;
import 'package:sologallery/core/theme/app_theme.dart';
import 'package:sologallery/features/memories/widgets/memory_card.dart';
import 'package:sologallery/services/permission_provider.dart';

import '../../../support/fake_photo_library_service.dart';

void main() {
  Future<void> pump(WidgetTester tester, MemorySummary memory) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: [
          photoLibraryServiceProvider.overrideWithValue(
            FakePhotoLibraryService(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Center(child: MemoryCard(memory: memory)),
          ),
        ),
      ),
    );
  }

  MemorySummary memory(String kind) => MemorySummary(
    id: 1,
    kind: kind,
    title: 'Early June',
    subtitle: '2025',
    coverAssetId: null,
    assetCount: 12,
  );

  testWidgets('kicks off with the memory kind above the title', (tester) async {
    await pump(tester, memory('trip'));
    await tester.pump();
    expect(find.text('TRIP'), findsOneWidget);
    expect(find.text('Early June'), findsOneWidget);
    expect(find.text('2025'), findsOneWidget);
  });

  testWidgets('the title is bold', (tester) async {
    await pump(tester, memory('trip'));
    await tester.pump();

    expect(
      tester.widget<Text>(find.text('Early June')).style?.fontWeight,
      FontWeight.w700,
    );
  });

  testWidgets(
    'spells a multi-word kind out rather than showing the enum name',
    (tester) async {
      await pump(tester, memory('onThisDay'));
      await tester.pump();
      expect(find.text('ON THIS DAY'), findsOneWidget);
      expect(find.textContaining('onThisDay'), findsNothing);
    },
  );

  testWidgets('says nothing at all for a kind this build does not know', (
    tester,
  ) async {
    // `memories.kind` is on-disk data. A row written by a newer build must
    // degrade to no kicker — never a raw string, never a crash.
    await pump(tester, memory('sometimeFutureKind'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('sometimeFutureKind'), findsNothing);
    expect(find.text('Early June'), findsOneWidget);
  });
}
