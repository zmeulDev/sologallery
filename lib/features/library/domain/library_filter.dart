/// How the Library home groups the timeline. Pure Dart — no Flutter or plugin
/// imports (see ARCHITECTURE.md#layers).
library;

/// The Library's time filter: how coarsely the grid is grouped.
///
/// Ordered coarsest-last, which is also the order the pills read in — the row
/// runs from "everything, as it comes" to progressively wider buckets, so
/// moving right is always a step back in the timeline.
enum LibraryFilter {
  /// Every month, newest first, with the memories carousel on top. The default.
  all,

  /// Only the rolling last seven days, as one flat grid.
  thisWeek,

  /// Month sections, with each year announced by a hero header.
  months,

  /// One section per year.
  year;

  /// The pill label.
  String get label => switch (this) {
    LibraryFilter.all => 'All',
    LibraryFilter.thisWeek => 'This week',
    LibraryFilter.months => 'Months',
    LibraryFilter.year => 'Year',
  };

  /// Whether this filter shows the memories carousel. Only [all] does: under a
  /// time filter the screen reads as pure time navigation, and a curated strip
  /// pinned above it belongs to neither the week nor the year below it.
  bool get showsMemories => this == LibraryFilter.all;
}
