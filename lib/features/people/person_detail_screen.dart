import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart' show Person;
import '../../core/theme/app_space.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/asset_grid.dart';
import '../../widgets/empty_state.dart';
import 'people_providers.dart';

/// One person's photos (`/person/:id`), reached from the People grid. The
/// app-bar title is the person's name (or "Person"); a rename action edits it.
class PersonDetailScreen extends ConsumerWidget {
  const PersonDetailScreen({super.key, required this.personId});

  final int personId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final person = ref.watch(personProvider(personId)).value;
    final assets = ref.watch(personAssetsProvider(personId));
    final name = person?.displayName;
    // Almost always empty, so the action only shows where it does something.
    final merged =
        ref.watch(mergedPeopleProvider(personId)).value ?? const <Person>[];

    return Scaffold(
      appBar: AppBar(
        title: Text(name ?? 'Person'),
        actions: [
          if (merged.isNotEmpty)
            AppButton.quiet(
              label: 'Separate',
              onPressed: () => _separate(context, ref, merged),
            ),
          if (merged.isNotEmpty)
            SizedBox(width: AppSpace.s4),
          Padding(
            padding: const EdgeInsets.only(right: AppSpace.s8),
            child: AppButton.quiet(
              label: 'Rename',
              onPressed: () => _rename(context, ref, name),
            ),
          ),
        ],
      ),
      body: assets.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => const EmptyState.note('Couldn\'t load these photos.'),
        data: (items) => items.isEmpty
            ? const EmptyState.note('No photos for this person.')
            : AssetGrid(items: items, hasMore: false, onLoadMore: _noop),
      ),
    );
  }

  static void _noop() {}

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    String? current,
  ) async {
    final result = await showAppTextInputDialog(
      context,
      title: 'Name this person',
      hint: 'Name',
      initial: current,
      confirmLabel: 'Save',
    );
    if (result != null) {
      await ref.read(peopleActionsProvider).rename(personId, result);
    }
  }

  /// Undoes every merge into this person, putting the absorbed clusters back on
  /// the People grid as entries of their own.
  Future<void> _separate(
    BuildContext context,
    WidgetRef ref,
    List<Person> merged,
  ) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Separate people?',
      message: merged.length == 1
          ? 'These photos split back into two people.'
          : 'These photos split back into ${merged.length + 1} people.',
      confirmLabel: 'Separate',
    );
    if (!confirmed) return;
    final actions = ref.read(peopleActionsProvider);
    for (final other in merged) {
      await actions.separate(other.id, from: personId);
    }
  }
}
