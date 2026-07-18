import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sologallery/features/library/domain/year_month.dart';
import 'package:sologallery/services/photo_library_service.dart';

/// On-device proof that month sections are windowed by **capture date**
/// (`DATE_TAKEN`), the same axis the grid orders and groups by — not by
/// `DATE_ADDED` (device-add date), which the classic `createTimeCond` uses.
///
/// This is the paired real-path counterpart to the host tests that use
/// `FakePhotoLibraryService` (CLAUDE.md "fake-pairing rule"): the fake can't
/// exercise photo_manager's native filter columns, so the DATE_ADDED/DATE_TAKEN
/// bug was invisible to `flutter test`.
///
/// Requires photo-library access already granted on the device (the user's
/// normal state) and at least one photo present. Run with:
///   flutter test integration_test/library_month_grouping_test.dart -d DEVICE_ID
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test('every month section contains only assets captured in that month',
      () async {
    final service = PhotoLibraryService();
    final access = await service.currentAccess();
    expect(
      access.canReadLibrary,
      isTrue,
      reason: 'Grant photo access to this app before running (open the app '
          'once and allow access).',
    );

    final months = await service.monthsInLibrary();
    expect(months, isNotEmpty, reason: 'Seed at least one dated photo.');

    final seenIds = <String>{};
    var totalAssertedMonths = 0;

    for (final month in months) {
      final summary = await service.monthSummary(month);
      if (summary == null) continue; // empty calendar month in the span
      totalAssertedMonths++;

      // Page through the whole month; assert the grouping axis == the filter
      // axis for every returned asset.
      var page = 0;
      var pageAssets = await service.monthAssets(month, page: page, pageSize: 90);
      var counted = 0;
      while (pageAssets.isNotEmpty) {
        for (final a in pageAssets) {
          expect(
            YearMonth.fromDate(a.createdAt),
            month,
            reason: 'Asset ${a.id} (captured ${a.createdAt}) surfaced under '
                '${month.label} — filter/group axis mismatch.',
          );
          expect(seenIds.add(a.id), isTrue,
              reason: 'Asset ${a.id} appeared in more than one section.');
          counted++;
        }
        page++;
        pageAssets = await service.monthAssets(month, page: page, pageSize: 90);
      }
      expect(counted, summary.count,
          reason: '${month.label}: paged $counted != summary count '
              '${summary.count}.');
    }

    expect(totalAssertedMonths, greaterThan(0));

    // Undated assets, if any, form the disjoint "Older" bucket.
    final older = await service.olderSummary();
    if (older != null) {
      var page = 0;
      var pageAssets = await service.olderAssets(page: page, pageSize: 90);
      while (pageAssets.isNotEmpty) {
        for (final a in pageAssets) {
          expect(seenIds.add(a.id), isTrue,
              reason: 'Undated asset ${a.id} also appeared in a month section.');
        }
        page++;
        pageAssets = await service.olderAssets(page: page, pageSize: 90);
      }
    }
  });
}
