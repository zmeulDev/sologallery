import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/asset_grid.dart';
import '../library/month_grid_screen.dart' show CenteredNote;
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

    return Scaffold(
      appBar: AppBar(
        title: Text(name ?? 'Person'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Rename',
            onPressed: () => _rename(context, ref, name),
          ),
        ],
      ),
      body: assets.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => const CenteredNote('Couldn\'t load these photos.'),
        data: (items) => items.isEmpty
            ? const CenteredNote('No photos for this person.')
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
    final controller = TextEditingController(text: current ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Name this person'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Name'),
          onSubmitted: (v) => Navigator.of(context).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null) {
      await ref.read(peopleActionsProvider).rename(personId, result);
    }
  }
}
