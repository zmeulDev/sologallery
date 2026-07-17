import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/placeholder_view.dart';

/// Albums list. Wired to [AlbumsDao] in Phase 3.
class AlbumsScreen extends ConsumerWidget {
  const AlbumsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Albums')),
      body: const PlaceholderView(
        icon: Icons.photo_album_outlined,
        message: 'Create albums to organize\nphotos your way.',
      ),
    );
  }
}
