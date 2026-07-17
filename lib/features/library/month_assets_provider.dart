import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/paged_assets_notifier.dart';
import '../../services/permission_provider.dart';
import '../../services/photo_library_service.dart';
import 'domain/year_month.dart';

/// Paged assets for a single month, backing the full-month grid. Keyed by
/// [YearMonth]; the family passes the month to the notifier constructor.
class MonthAssetsNotifier extends PagedAssetsNotifier {
  MonthAssetsNotifier(this.month);

  final YearMonth month;

  @override
  Future<List<AssetRef>> fetchPage(int page, int pageSize) {
    return ref
        .read(photoLibraryServiceProvider)
        .monthAssets(month, page: page, pageSize: pageSize);
  }
}

final monthAssetsProvider = AsyncNotifierProvider.autoDispose
    .family<MonthAssetsNotifier, List<AssetRef>, YearMonth>(
  MonthAssetsNotifier.new,
);
