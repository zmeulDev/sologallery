import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/logging_config.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // The default 100MB image cache is too small for a photo app: a few
  // full-res detail previews (~12MB each) evict the grid thumbnails and force a
  // re-decode on scroll-back. 256MB lets the visible grid + several open detail
  // pages coexist. Flutter clears the cache automatically on system memory
  // pressure (`PaintingBinding.handleMemoryPressure`), so a larger cap is safe.
  imageCache.maximumSizeBytes = 256 * 1024 * 1024;
  configureLogging();
  runApp(const ProviderScope(child: SoloGalleryApp()));
}
