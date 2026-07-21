import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/features/library/domain/library_filter.dart';

void main() {
  test('every filter has a label', () {
    expect(
      [for (final f in LibraryFilter.values) f.label],
      ['All', 'This week', 'Months', 'Year'],
    );
  });

  test('labels are unique — the pills are the only way to tell them apart', () {
    final labels = {for (final f in LibraryFilter.values) f.label};
    expect(labels, hasLength(LibraryFilter.values.length));
  });

  test('only the default filter shows the memories carousel', () {
    expect(LibraryFilter.all.showsMemories, isTrue);
    for (final f in LibraryFilter.values.where((f) => f != LibraryFilter.all)) {
      expect(f.showsMemories, isFalse, reason: '${f.name} is a time filter');
    }
  });

  test('all is the first value, so it reads as the default', () {
    expect(LibraryFilter.values.first, LibraryFilter.all);
  });
}
