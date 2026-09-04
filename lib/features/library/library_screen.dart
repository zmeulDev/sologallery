import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_space.dart';
import '../../services/permission_provider.dart';
import '../../services/photo_library_service.dart';
import '../../widgets/circle_icon_button.dart';
import '../../widgets/limited_access_banner.dart';
import 'domain/library_filter.dart';
import 'library_providers.dart';
import 'widgets/month_timeline.dart';
import 'widgets/this_week_list.dart';
import 'widgets/year_list.dart';

/// Home gallery: photos grouped by time, newest first, read from the
/// `photo_asset` cache. The filter bar sets how coarsely — every month, the
/// last seven days, months under year heroes, or one section per year. Month
/// and year sections show up to six previews and a "View all" control.
class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(permissionProvider);
    final filter = ref.watch(libraryFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Library'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpace.s16),
            child: Center(
              child: CircleIconButton.surface(
                icon: Icons.settings_rounded,
                tooltip: 'Settings',
                onPressed: () => context.push('/settings'),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (access == PhotoAccess.limited)
            LimitedAccessBanner(
              onSelectMore: () =>
                  ref.read(permissionProvider.notifier).presentLimited(),
            ),
          // Each filter owns its own query, and so its own loading and empty
          // states — a shared `.when` would make the week wait on the month
          // counts it never reads. The filter bar lives inside each filter's
          // scrollable body so it sits immediately above the content it controls
          // and rides below the memories carousel on `All`.
          Expanded(
            child: KeyedSubtree(
              key: ValueKey(filter),
              child: switch (filter) {
                LibraryFilter.thisWeek => const ThisWeekList(),
                LibraryFilter.year => const YearList(),
                LibraryFilter.all ||
                LibraryFilter.months => MonthTimeline(filter: filter),
              },
            ),
          ),
        ],
      ),
    );
  }
}
