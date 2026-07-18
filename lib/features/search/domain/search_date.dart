// Pure-Dart search-query parsing for the metadata Search screen. No Flutter or
// photo_manager imports — the service maps MediaTypeFilter onto a RequestType,
// keeping plugin types out of the domain (docs/spec.md#architecture).

/// A half-open capture-date window `[start, endExclusive)` parsed from a text
/// query. Used to scope photo results to a year or a month.
class DateWindow {
  const DateWindow(this.start, this.endExclusive);

  final DateTime start;
  final DateTime endExclusive;

  @override
  bool operator ==(Object other) =>
      other is DateWindow &&
      other.start == start &&
      other.endExclusive == endExclusive;

  @override
  int get hashCode => Object.hash(start, endExclusive);

  @override
  String toString() => 'DateWindow($start .. $endExclusive)';
}

/// The media-type facet for the Search grid. Maps to `photo_manager`
/// `RequestType` inside `PhotoLibraryService`; stays plugin-free here.
enum MediaTypeFilter { all, photos, videos }

/// Month names → 1-based month, full and 3-letter abbreviation (English).
const _months = <String, int>{
  'january': 1, 'jan': 1,
  'february': 2, 'feb': 2,
  'march': 3, 'mar': 3,
  'april': 4, 'apr': 4,
  'may': 5,
  'june': 6, 'jun': 6,
  'july': 7, 'jul': 7,
  'august': 8, 'aug': 8,
  'september': 9, 'sep': 9, 'sept': 9,
  'october': 10, 'oct': 10,
  'november': 11, 'nov': 11,
  'december': 12, 'dec': 12,
};

/// Parses a date phrase into a capture-date [DateWindow], or null when the text
/// isn't a recognizable date. Case-insensitive; surrounding whitespace ignored.
///
/// Recognized forms:
/// - year: `2026` → all of 2026
/// - month + year: `June 2026`, `jun 2026`, `2026 June` → that month
/// - numeric month/year: `2026-06`, `2026/06`, `06/2026` → that month
///
/// A bare month with no year (`june`) is intentionally not a date here — it is
/// ambiguous across years and can't be expressed as a single window; callers
/// treat such text as an album-name query instead.
DateWindow? parseDateQuery(String raw) {
  final q = raw.trim().toLowerCase();
  if (q.isEmpty) return null;

  // Split on whitespace and the common date separators.
  final tokens =
      q.split(RegExp(r'[\s/\-.]+')).where((t) => t.isNotEmpty).toList();

  if (tokens.length == 1) {
    final year = _asYear(tokens[0]);
    if (year != null) return _yearWindow(year);
    return null;
  }

  if (tokens.length == 2) {
    final a = tokens[0];
    final b = tokens[1];
    // month + year in either order (word or number month).
    final m1 = _asMonth(a);
    final y1 = _asYear(b);
    if (m1 != null && y1 != null) return _monthWindow(y1, m1);
    final y2 = _asYear(a);
    final m2 = _asMonth(b);
    if (y2 != null && m2 != null) return _monthWindow(y2, m2);
  }

  return null;
}

/// A 4-digit year token (1900–2999), else null.
int? _asYear(String token) {
  if (!RegExp(r'^\d{4}$').hasMatch(token)) return null;
  final year = int.parse(token);
  return (year >= 1900 && year <= 2999) ? year : null;
}

/// A month token — a name/abbreviation or a 1–12 number, else null.
int? _asMonth(String token) {
  final named = _months[token];
  if (named != null) return named;
  if (RegExp(r'^\d{1,2}$').hasMatch(token)) {
    final n = int.parse(token);
    if (n >= 1 && n <= 12) return n;
  }
  return null;
}

DateWindow _yearWindow(int year) =>
    DateWindow(DateTime(year), DateTime(year + 1));

DateWindow _monthWindow(int year, int month) =>
    DateWindow(DateTime(year, month), DateTime(year, month + 1));
