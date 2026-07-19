import 'dart:io' show Directory, File;

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider/path_provider.dart';

/// Resolves a test fixture that is **pushed to the device**, not bundled into
/// the app.
///
/// The fixture used to ride along in `pubspec.yaml`'s `flutter: assets:`, which
/// shipped a file called `synthetic_face.jpg` inside a released privacy-first
/// photo app — a fair thing for a reviewer to raise an eyebrow at. It now lives
/// in the app-private external directory, which is **not** MediaStore-indexed,
/// so it still never pollutes the real photo library (the original reason for
/// bundling it).
///
/// Push before running, per test_assets/README.md:
/// ```bash
/// adb push assets/test_fixtures/synthetic_face.jpg \
///   /sdcard/Android/data/com.zmeul.sologallery/files/
/// ```
Future<File> fixtureFile(String name) async {
  final candidates = <Directory?>[
    // Android: /sdcard/Android/data/<pkg>/files — where `adb push` lands.
    ...(await getExternalStorageDirectories() ?? const <Directory>[]),
    await getApplicationDocumentsDirectory(),
    await getTemporaryDirectory(),
  ];

  for (final dir in candidates) {
    if (dir == null) continue;
    final file = File('${dir.path}/$name');
    if (file.existsSync()) return file;
  }

  fail(
    'Fixture "$name" is not on the device. Push it first:\n'
    '  adb push assets/test_fixtures/$name '
    '/sdcard/Android/data/com.zmeul.sologallery/files/\n'
    'Searched: ${candidates.nonNulls.map((d) => d.path).join(", ")}',
  );
}
