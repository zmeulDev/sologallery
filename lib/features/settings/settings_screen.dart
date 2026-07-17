import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/placeholder_view.dart';

/// Settings. Permissions, theme, and storage controls land here in later
/// phases.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: const PlaceholderView(
        icon: Icons.settings_outlined,
        message: 'App settings\nwill live here.',
      ),
    );
  }
}
