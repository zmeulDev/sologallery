import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/database/database_provider.dart';

/// Cached-library totals for the Settings stats section (photos incl. videos,
/// and the video subset), reactive over the `photo_asset` cache.
final libraryTotalsProvider =
    StreamProvider.autoDispose<({int photos, int videos})>((ref) {
  return ref.watch(indexDaoProvider).watchLibraryTotals();
});

/// Number of clustered people, reactive — derived from the People summaries.
final peopleCountProvider = StreamProvider.autoDispose<int>((ref) {
  return ref
      .watch(facesDaoProvider)
      .watchPersonSummaries()
      .map((people) => people.length);
});

/// The app version + build number for the About section (e.g. "1.0.0 (1)").
/// Overridden in widget tests (no platform channel on the host). Kept alive
/// app-wide: the version never changes across a session, so autoDispose would
/// just re-run `PackageInfo.fromPlatform()` every time Settings re-opens.
final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return '${info.version} (${info.buildNumber})';
});
