import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sologallery/core/database/app_database.dart';
import 'package:sologallery/features/library/domain/year_month.dart';
import 'package:sologallery/services/photo_library_service.dart';

/// On-device proof that the cache-backed grid groups by **capture date**
/// (`DATE_TAKEN`), the same axis it orders by — not by `DATE_ADDED` (device-add
/// date), which the classic `createTimeCond` uses. The grid now reads the
/// `photo_asset` cache, so this sweeps the live library into a fresh cache
/// (exactly as [IndexingService] does, via [PhotoLibraryService.libraryMetadataPage])
/// and asserts the DAO's month grouping over real device metadata.
///
/// This is the paired real-path counterpart to the host tests that use
/// `FakePhotoLibraryService` (AGENTS.md "fake-pairing rule"): the fake can't
/// exercise photo_manager's native filter columns, so the DATE_ADDED/DATE_TAKEN
/// bug was invisible to `flutter test`.
///
/// Requires photo-library access already granted on the device (the user's
/// normal state) and at least one photo present. Run with:
///   flutter test integration_test/library_month_grouping_test.dart -d DEVICE_ID
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test('cache-backed month sections contain only assets captured that month',
      () async {
    final service = PhotoLibraryService();
    final access = await service.currentAccess();
    expect(
      access.canReadLibrary,
      isTrue,
      reason: 'Grant photo access to this app before running (open the app '
          'once and allow access).',
    );

    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    // Sweep the live library into the cache exactly as the indexer does.
    final live = <String>{};
    for (final dated in const [true, false]) {
      var page = 0;
      while (true) {
        final rows = await service.libraryMetadataPage(
          dated: dated,
          page: page,
          pageSize: 500,
        );
        if (rows.isEmpty) break;
        await db.indexDao.upsertMetadata([
          for (final r in rows)
            (
              id: r.id,
              createdAt: r.createdAt,
              isVideo: r.isVideo,
              width: r.width,
              height: r.height,
              isDated: dated,
            ),
        ]);
        for (final r in rows) {
          live.add(r.id);
        }
        page++;
      }
    }
    expect(live, isNotEmpty, reason: 'Seed at least one photo on the device.');

    final counts = await db.indexDao.watchMonthCounts().first;
    expect(counts, isNotEmpty, reason: 'Seed at least one dated photo.');

    final seenIds = <String>{};
    for (final entry in counts) {
      var offset = 0;
      var counted = 0;
      while (true) {
        final page =
            await db.indexDao.monthAssets(entry.month, limit: 90, offset: offset);
        if (page.isEmpty) break;
        for (final a in page) {
          expect(
            YearMonth.fromDate(a.createdAt),
            entry.month,
            reason: 'Asset ${a.id} (captured ${a.createdAt}) surfaced under '
                '${entry.month.label} — filter/group axis mismatch.',
          );
          expect(seenIds.add(a.id), isTrue,
              reason: 'Asset ${a.id} appeared in more than one section.');
          counted++;
        }
        offset += 90;
      }
      expect(counted, entry.count,
          reason: '${entry.month.label}: paged $counted != count ${entry.count}.');
    }

    // Undated assets, if any, form the disjoint "Older" bucket.
    final olderCount = await db.indexDao.watchOlderCount().first;
    if (olderCount > 0) {
      // The growing window is bounded by the count, so one read covers the
      // whole bucket — there is no second page to miss.
      final older = await db.indexDao.watchOlderAssets(limit: olderCount).first;
      expect(older, hasLength(olderCount),
          reason: 'Older window returned ${older.length} of $olderCount — the '
              'disjointness check below would silently skip the remainder.');
      for (final a in older) {
        expect(seenIds.add(a.id), isTrue,
            reason: 'Undated asset ${a.id} also appeared in a month section.');
      }
    }
  });
}
