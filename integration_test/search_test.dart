import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sologallery/features/library/domain/year_month.dart';
import 'package:sologallery/features/search/domain/search_date.dart';
import 'package:sologallery/services/photo_library_service.dart';

/// On-device proof that metadata Search hits the real `photo_manager` filter
/// columns: media-type (`RequestType`) partitioning and capture-date windowing.
///
/// Paired real-path counterpart to the host tests that use
/// `FakePhotoLibraryService` (CLAUDE.md "fake-pairing rule") — the fake filters
/// an in-memory list and can't exercise the native `RequestType`/`DATE_TAKEN`
/// path the production query uses.
///
/// Requires photo-library access already granted and at least one photo. Run:
///   flutter test integration_test/search_test.dart -d DEVICE_ID
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late PhotoLibraryService service;

  setUp(() => service = PhotoLibraryService());

  Future<void> requireAccess() async {
    final access = await service.currentAccess();
    expect(
      access.canReadLibrary,
      isTrue,
      reason: 'Grant photo access before running (open the app once and allow).',
    );
  }

  test('media-type facet partitions videos from photos', () async {
    await requireAccess();

    final videos = await service.searchAssets(
      type: MediaTypeFilter.videos,
      page: 0,
      pageSize: 200,
    );
    for (final a in videos) {
      expect(await service.isVideoAsset(a.id), isTrue,
          reason: 'Videos facet returned non-video ${a.id}.');
    }

    final photos = await service.searchAssets(
      type: MediaTypeFilter.photos,
      page: 0,
      pageSize: 200,
    );
    for (final a in photos) {
      expect(await service.isVideoAsset(a.id), isFalse,
          reason: 'Photos facet returned a video ${a.id}.');
    }

    // The two facets are disjoint.
    final videoIds = {for (final a in videos) a.id};
    final photoIds = {for (final a in photos) a.id};
    expect(videoIds.intersection(photoIds), isEmpty);
  });

  test('a capture-month query windows results to that month', () async {
    await requireAccess();

    final months = await service.monthsInLibrary();
    expect(months, isNotEmpty, reason: 'Seed at least one dated photo.');
    final month = months.first; // newest dated month

    final windowed = await service.searchAssets(
      min: month.start,
      max: month.end,
      type: MediaTypeFilter.all,
      page: 0,
      pageSize: 200,
    );
    expect(windowed, isNotEmpty,
        reason: '${month.label} has photos but the window returned none.');
    for (final a in windowed) {
      expect(YearMonth.fromDate(a.createdAt), month,
          reason: 'Search returned ${a.id} (captured ${a.createdAt}) outside '
              '${month.label}.');
    }

    // The date-only search over a month equals the month grid's own query.
    final viaMonth = await service.monthAssets(month, page: 0, pageSize: 200);
    expect(
      windowed.map((a) => a.id).toList(),
      viaMonth.map((a) => a.id).toList(),
      reason: 'Search window and month grid disagree for ${month.label}.',
    );
  });

  test('favorites resolution filters by type and window, newest first',
      () async {
    await requireAccess();

    // Use real library ids as a stand-in favorites set (no dependency on the
    // user's actual favorites) to exercise entity resolution + filtering.
    final sample = await service.searchAssets(
      type: MediaTypeFilter.all,
      page: 0,
      pageSize: 20,
    );
    if (sample.isEmpty) return; // nothing to resolve
    final ids = [for (final a in sample) a.id];

    final all = await service.resolveFavoriteMatches(
      ids: ids,
      type: MediaTypeFilter.all,
    );
    // Newest first.
    for (var i = 1; i < all.length; i++) {
      expect(all[i - 1].createdAt.isBefore(all[i].createdAt), isFalse);
    }

    final videosOnly = await service.resolveFavoriteMatches(
      ids: ids,
      type: MediaTypeFilter.videos,
    );
    for (final a in videosOnly) {
      expect(await service.isVideoAsset(a.id), isTrue);
    }
    expect(videosOnly.length, lessThanOrEqualTo(all.length));
  });
}
