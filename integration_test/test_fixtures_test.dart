import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sologallery/services/ml_service.dart';

import 'support/fixture_file.dart';

/// Validates the pushed test fixtures against the **real** ML models, so other
/// on-device tests can rely on them instead of on whatever is in the
/// developer's camera roll.
///
/// The face fixture in particular is a *positive control*: it exists so
/// `consent_test.dart` can prove that "no faces were detected" means the
/// consent gate held, not that there was nothing to find. A drawn face is not
/// guaranteed to trip a detector trained on photographs, so that claim has to
/// be checked on device rather than assumed.
///
/// The fixture is pushed to the device, not bundled into the app — see
/// support/fixture_file.dart and test_assets/README.md.
///
/// Run with: flutter test integration_test/test_fixtures_test.dart -d DEVICE_ID
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test('the synthetic face fixture is detectable by the real detector',
      () async {
    final file = await fixtureFile('synthetic_face.jpg');
    final bytes = await file.readAsBytes();

    final worker = MlWorkerController();
    addTearDown(worker.dispose);

    final analysis = await worker.analyze(bytes: bytes);

    expect(
      analysis.faces,
      isNotEmpty,
      reason: 'the synthetic face fixture is no longer detected — regenerate it '
          '(tool/gen_test_assets.dart) or replace it with a photographic face, '
          'or every "no faces without consent" assertion becomes vacuous',
    );
    // A real embedding, not a zero vector — proves the tflite FFI path ran.
    expect(analysis.faces.first.embedding.length, greaterThan(0));
    expect(
      analysis.faces.first.embedding.any((v) => v != 0),
      isTrue,
      reason: 'MobileFaceNet returned an all-zero embedding',
    );
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('declining consent suppresses the fixture face too', () async {
    final file = await fixtureFile('synthetic_face.jpg');
    final bytes = await file.readAsBytes();

    final worker = MlWorkerController();
    addTearDown(worker.dispose);

    // Same image the control above proves is detectable — so an empty result
    // here can only be the gate.
    final declined = await worker.analyze(bytes: bytes, faces: false);
    expect(declined.faces, isEmpty);

    final noContent = await worker.analyze(bytes: bytes, content: false);
    expect(noContent.labels, isEmpty);
    expect(noContent.text, isEmpty);
  }, timeout: const Timeout(Duration(minutes: 5)));
}
