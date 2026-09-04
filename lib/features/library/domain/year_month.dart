/// A calendar month, the grouping unit for the Library grid.
///
/// Pure Dart — no Flutter or plugin imports (see ARCHITECTURE.md#layers), so
/// it is unit-testable on the host with zero mocking.
class YearMonth implements Comparable<YearMonth> {
  const YearMonth(this.year, this.month)
      : assert(month >= 1 && month <= 12, 'month must be 1..12');

  factory YearMonth.fromDate(DateTime date) => YearMonth(date.year, date.month);

  final int year;
  final int month;

  /// Stable key used in the `/month/:key` route and elsewhere, e.g. `2026-07`.
  String get key => '$year-${month.toString().padLeft(2, '0')}';

  /// Parses a [key] produced by [key]; returns null if malformed.
  static YearMonth? tryParseKey(String key) {
    final parts = key.split('-');
    if (parts.length != 2) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    if (year == null || month == null || month < 1 || month > 12) return null;
    return YearMonth(year, month);
  }

  /// Human-readable label, e.g. `July 2026`.
  String get label => '${_monthNames[month - 1]} $year';

  /// First instant of the month (inclusive lower bound for queries).
  DateTime get start => DateTime(year, month);

  /// First instant of the following month (exclusive upper bound).
  DateTime get end =>
      month == 12 ? DateTime(year + 1) : DateTime(year, month + 1);

  @override
  int compareTo(YearMonth other) =>
      year != other.year ? year.compareTo(other.year) : month.compareTo(other.month);

  @override
  bool operator ==(Object other) =>
      other is YearMonth && other.year == year && other.month == month;

  @override
  int get hashCode => Object.hash(year, month);

  @override
  String toString() => 'YearMonth($key)';
}

const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];
