import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/placeholder_view.dart';

/// Saved (favorites) grid. Wired to [FavoritesDao] in Phase 3.
class SavedScreen extends ConsumerWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Saved')),
      body: const PlaceholderView(
        icon: Icons.favorite_border,
        message: 'Photos you favorite\nwill be collected here.',
      ),
    );
  }
}
