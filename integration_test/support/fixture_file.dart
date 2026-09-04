import 'dart:io' show Directory, File;

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider/path_provider.dart';

/// Resolves a test fixture that is **pushed to the device's app-private
/// storage**, not bundled into the app.
///
/// The fixture used to ride along in `pubspec.yaml`'s `flutter: assets:`, which
/// shipped a file called `synthetic_face.jpg` inside a released privacy-first
/// photo app — a fair thing for a reviewer to raise an eyebrow at. It now lives
/// in app-private storage, which is **not** MediaStore/PhotoKit-indexed, so it
/// still never pollutes the real photo library (the original reason for
/// bundling it).
///
/// Push before running, per test_assets/README.md:
/// ```bash
/// # Android — app-external files dir:
/// adb push test_assets/synthetic_face.jpg \
///   /sdcard/Android/data/com.zmeul.sologallery/files/
/// # iOS device — app data container's Documents dir:
/// xcrun devicectl device copy to --device <udid> \
///   --domain-type appDataContainer --domain-identifier com.zmeul.sologallery \
///   --source test_assets/synthetic_face.jpg --destination Documents
/// ```
Future<File> fixtureFile(String name) async {
  // Android: /sdcard/Android/data/<pkg>/files — where `adb push` lands.
  // `getExternalStorageDirectories` *throws* `UnsupportedError` on iOS/macOS
  // (not null), so guard it — the iOS fixture lives in the documents dir below.
  List<Directory> external;
  try {
    external = await getExternalStorageDirectories() ?? const <Directory>[];
  } on UnsupportedError {
    external = const <Directory>[];
  }

  final candidates = <Directory?>[
    ...external,
    // iOS device: the app data container's Documents dir — where
    // `devicectl device copy to --domain-type appDataContainer` lands.
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
    '  Android: adb push test_assets/$name '
    '/sdcard/Android/data/com.zmeul.sologallery/files/\n'
    '  iOS:     xcrun devicectl device copy to --device <udid> '
    '--domain-type appDataContainer '
    '--domain-identifier com.zmeul.sologallery '
    '--source test_assets/$name --destination Documents\n'
    'Searched: ${candidates.nonNulls.map((d) => d.path).join(", ")}',
  );
}
