import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../widgets/filter_pill.dart';
import '../domain/library_filter.dart';
import '../library_providers.dart';

/// The Library's time-grouping row: one [FilterPill] per [LibraryFilter],
/// single-select. Same anatomy and metrics as the Search facet row, so the two
/// filter surfaces read as one control rather than two dialects.
///
/// Horizontally scrollable because the four labels can outrun a narrow screen
/// at large text scales. It lives inside each Library filter's scrollable body
/// so it sits immediately above the content it controls, and below the
/// memories carousel on [LibraryFilter.all].
class LibraryFilterBar extends ConsumerWidget {
  const LibraryFilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(libraryFilterProvider);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          for (final filter in LibraryFilter.values) ...[
            if (filter != LibraryFilter.values.first) const SizedBox(width: 8),
            FilterPill(
              label: filter.label,
              selected: filter == active,
              onTap: () => ref.read(libraryFilterProvider.notifier).set(filter),
            ),
          ],
        ],
      ),
    );
  }
}
