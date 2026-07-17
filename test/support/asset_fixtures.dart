import 'package:sologallery/services/photo_library_service.dart';

/// Builds [count] fake assets all within [year]/[month], with distinct ids and
/// descending creation times (newest first mirrors the real service).
List<AssetRef> assetsInMonth(int year, int month, int count, {String? prefix}) {
  return [
    for (var i = 0; i < count; i++)
      AssetRef(
        id: '${prefix ?? '$year-$month'}-$i',
        // Day 28 down to keep every entry inside the month.
        createdAt: DateTime(year, month, 28, 12).subtract(Duration(minutes: i)),
      ),
  ];
}
