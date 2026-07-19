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
