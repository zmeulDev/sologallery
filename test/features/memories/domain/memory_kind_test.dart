import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/features/memories/domain/memory_kind.dart';

void main() {
  group('memoryKindFromName', () {
    test('round-trips every persisted name', () {
      // The names are the on-disk format; a rename needs a migration, and this
      // is what would notice one going in without it.
      for (final kind in MemoryKind.values) {
        expect(memoryKindFromName(kind.name), kind);
      }
    });

    test('returns null for a name this build does not know', () {
      // A row written by a newer build must degrade, not throw.
      expect(memoryKindFromName('sometimeFutureKind'), isNull);
      expect(memoryKindFromName(''), isNull);
    });

    test('is case-sensitive, matching how the name is persisted', () {
      expect(memoryKindFromName('onthisday'), isNull);
      expect(memoryKindFromName('onThisDay'), MemoryKind.onThisDay);
    });
  });

  group('label', () {
    test('gives every kind display text, none of it an enum name', () {
      for (final kind in MemoryKind.values) {
        expect(kind.label, isNotEmpty);
        expect(kind.label, isNot(kind.name));
      }
    });

    test('spells out the multi-word kind', () {
      expect(MemoryKind.onThisDay.label, 'On this day');
    });
  });
}
