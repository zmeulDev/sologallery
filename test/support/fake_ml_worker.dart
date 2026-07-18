import 'package:sologallery/services/ml_service.dart';

/// In-memory [MlWorker] for host tests — returns canned analysis without
/// spawning an isolate or touching ML Kit. Paired with the on-device
/// `integration_test/ml_indexing_test.dart` exercising the real worker
/// (CLAUDE.md fake-pairing rule — the isolate binding + bundled models can't run
/// on the host).
class FakeMlWorker implements MlWorker {
  FakeMlWorker({
    this.labels = const [('Dog', 0.9)],
    this.text = '',
    this.faces = const [],
  });

  /// Labels returned for every [analyzeFile] call.
  final List<Label> labels;

  /// OCR text returned for every [analyzeFile] call.
  final String text;

  /// Faces returned for every [analyzeFile] call.
  final List<DetectedFace> faces;

  /// Paths passed to [analyzeFile], in order (call count = length).
  final List<String> calls = [];

  var disposed = false;

  @override
  Future<ImageAnalysis> analyzeFile(String jpegPath) async {
    calls.add(jpegPath);
    return (labels: labels, text: text, faces: faces);
  }

  @override
  void dispose() => disposed = true;
}
