/// The four kinds of auto-curated memory the app generates.
///
/// Persisted as [MemoryKind.name] in `memories.kind`, so the names are part of
/// the on-disk format — renaming one needs a migration.
enum MemoryKind {
  /// Same local month+day in a previous year.
  onThisDay,

  /// A burst of photos bounded by quiet periods — a trip or event. Titled by
  /// date range only; the app stores no GPS.
  trip,

  /// A recurring subject from on-device ML labels ("Dogs", "Food").
  theme,

  /// A clustered, user-named person over time.
  person,
}

/// The persisted [MemoryKind.name] back to its enum value, or `null` if the
/// string names no kind this build knows.
///
/// Nullable rather than throwing: `memories.kind` is on-disk data, and a row
/// written by a newer build must degrade to "no kicker" instead of taking down
/// the Library.
MemoryKind? memoryKindFromName(String name) {
  for (final kind in MemoryKind.values) {
    if (kind.name == name) return kind;
  }
  return null;
}

extension MemoryKindLabel on MemoryKind {
  /// Display text for the memory card's kicker — what *sort* of memory this is,
  /// above the title that says which one.
  String get label => switch (this) {
    MemoryKind.onThisDay => 'On this day',
    MemoryKind.trip => 'Trip',
    MemoryKind.theme => 'Theme',
    MemoryKind.person => 'Person',
  };
}
