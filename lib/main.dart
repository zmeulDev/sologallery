import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/logging_config.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  configureLogging();
  runApp(const ProviderScope(child: SoloGalleryApp()));
}
