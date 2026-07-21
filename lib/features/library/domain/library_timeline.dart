/// Flattening the Library home's grouped timeline into display rows. Pure Dart
/// — no Flutter or plugin imports (see docs/spec.md#architecture).
library;

import 'library_filter.dart';
import 'year_month.dart';

/// One row of the month timeline, resolved before the list is built.
///
/// Flattening first is what lets year heroes interleave with month sections
/// under one `ListView.builder`: the builder needs a stable index → row
/// mapping, which an "insert a header when the year changes" check inside the
/// builder can't give it — that check only sees the row it was asked for, and
/// the builder may be asked for rows in any order.
sealed class TimelineRow {
  const TimelineRow();
}

/// The memories carousel, above the timeline rather than part of it.
class MemoriesRow extends TimelineRow {
  const MemoriesRow();
}

/// A year hero announcing the months below it, carrying that year's total.
class YearRow extends TimelineRow {
  const YearRow(this.year, this.count);

  final int year;
  final int count;
}

/// One calendar-month section.
class MonthRow extends TimelineRow {
  const MonthRow(this.month, this.count);

  final YearMonth month;
  final int count;
}

/// The trailing bucket of undated assets.
class OlderRow extends TimelineRow {
  const OlderRow(this.count);

  final int count;
}

/// Flattens month [counts] (newest first) into the display rows for [filter].
///
/// Under [LibraryFilter.months] a [YearRow] precedes the first month of each
/// year, carrying that year's total — summed from the counts already in hand
/// rather than costing a second query. Undated assets belong to no year, so
/// [OlderRow] always stays outside the hero grouping.
List<TimelineRow> buildTimelineRows({
  required List<({YearMonth month, int count})> counts,
  required int olderCount,
  required LibraryFilter filter,
}) {
  final rows = <TimelineRow>[if (filter.showsMemories) const MemoriesRow()];
  int? lastYear;
  for (final entry in counts) {
    final year = entry.month.year;
    if (filter == LibraryFilter.months && year != lastYear) {
      final total = counts
          .where((c) => c.month.year == year)
          .fold(0, (sum, c) => sum + c.count);
      rows.add(YearRow(year, total));
    }
    lastYear = year;
    rows.add(MonthRow(entry.month, entry.count));
  }
  if (olderCount > 0) rows.add(OlderRow(olderCount));
  return rows;
}
