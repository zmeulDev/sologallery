import 'dart:async';

import 'package:alchemist/alchemist.dart';

/// Global test bootstrap. Configures Alchemist to produce only platform-agnostic
/// **CI goldens** (no host-platform variants), so design-system golden files are
/// stable across machines and CI. Non-golden tests are unaffected.
Future<void> testExecutable(FutureOr<void> Function() testMain) {
  return AlchemistConfig.runWithConfig(
    config: const AlchemistConfig(
      platformGoldensConfig: PlatformGoldensConfig(enabled: false),
    ),
    run: () async => testMain(),
  );
}
