import 'dart:io';
import 'dart:typed_data';

import 'package:sologallery/services/photo_library_service.dart';

/// Real, decodable PNG bytes (the small test asset), for tests that must supply
/// non-null thumbnail bytes the widget will actually decode — e.g. asserting a
/// grid forwards `initialBytes`. Dummy bytes like `[1,2,3]` trip an
/// "Invalid image data" codec exception when AssetThumbnail renders them.
final Uint8List validThumbnailBytes =
    File('test_assets/small_png.png').readAsBytesSync();

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
