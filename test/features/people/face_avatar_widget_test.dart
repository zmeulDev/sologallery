import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/core/theme/app_theme.dart';
import 'package:sologallery/features/people/people_providers.dart';
import 'package:sologallery/features/people/widgets/face_avatar.dart';

// `FaceAvatar.cover` lets a caller that already resolved a batch of covers
// (the People grid/strip, via `personCoversProvider` — see B2) hand it
// straight to the avatar instead of the widget re-reading `personCoverProvider`
// itself. These tests pin that wiring: a supplied cover short-circuits the
// provider entirely, and omitting it preserves the old per-avatar fallback.
void main() {
  const cover = (
    assetId: 'supplied-asset',
    left: 0.1,
    top: 0.1,
    right: 0.3,
    bottom: 0.3,
  );

  testWidgets(
    'given an explicit cover, never reads personCoverProvider',
    (tester) async {
      var providerReads = 0;
      final requested = <FaceThumbRequest>[];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            // If FaceAvatar fell back to the provider despite having a cover,
            // this would be invoked.
            personCoverProvider.overrideWith((ref, id) async {
              providerReads++;
              return null;
            }),
            faceThumbProvider.overrideWith((ref, req) async {
              requested.add(req);
              return null;
            }),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(
              body: FaceAvatar(personId: 1, cover: cover),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(providerReads, 0, reason: 'the supplied cover must short-circuit '
          'the `??` before personCoverProvider is ever watched');
      // The widget still renders *from* the supplied cover: it goes on to ask
      // for a thumbnail keyed on that cover's asset, not a placeholder-early-
      // return as it would for a null cover.
      expect(requested, isNotEmpty);
      expect(requested.every((r) => r.assetId == 'supplied-asset'), isTrue);
    },
  );

  testWidgets(
    'without a cover, falls back to personCoverProvider',
    (tester) async {
      var providerReads = 0;
      final requested = <FaceThumbRequest>[];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            personCoverProvider.overrideWith((ref, id) async {
              providerReads++;
              return cover;
            }),
            faceThumbProvider.overrideWith((ref, req) async {
              requested.add(req);
              return null;
            }),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(body: FaceAvatar(personId: 1)),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(providerReads, greaterThan(0));
      expect(requested, isNotEmpty);
      expect(requested.every((r) => r.assetId == 'supplied-asset'), isTrue);
    },
  );

  testWidgets(
    'a null cover from the provider still renders the placeholder',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            personCoverProvider.overrideWith((ref, id) async => null),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(body: FaceAvatar(personId: 1)),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(Container), findsWidgets);
    },
  );
}
