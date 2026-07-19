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
    this.beforeAnalyze,
  });

  /// Awaited at the start of every [analyzeFile], with the 0-based call index.
  /// Lets a test hold a pass open mid-flight — the window in which consent
  /// changes used to be lost.
  final Future<void> Function(int callIndex)? beforeAnalyze;

  /// Labels returned for every [analyzeFile] call.
  final List<Label> labels;

  /// OCR text returned for every [analyzeFile] call.
  final String text;

  /// Faces returned for every [analyzeFile] call.
  final List<DetectedFace> faces;

  /// Label/face image paths passed to [analyzeFile], in order (call count =
  /// length).
  final List<String> calls = [];

  /// The `ocrPath` passed alongside each call (null when OCR fell back to the
  /// 512 image) — lets tests assert the higher-res OCR pass was wired up.
  final List<String?> ocrCalls = [];

  /// The consent flags passed with each call — let tests assert the user's
  /// choices actually reach the worker.
  final List<bool> faceRequests = [];
  final List<bool> contentRequests = [];

  var disposed = false;

  @override
  Future<ImageAnalysis> analyzeFile(
    String jpegPath, {
    String? ocrPath,
    bool content = true,
    bool faces = true,
  }) async {
    await beforeAnalyze?.call(calls.length);
    calls.add(jpegPath);
    ocrCalls.add(ocrPath);
    faceRequests.add(faces);
    contentRequests.add(content);
    // Mirrors the real worker's contract: no consent, no result — so a caller
    // that forgets to gate its insert still can't smuggle derived data through.
    return (
      labels: content ? labels : const <Label>[],
      text: content ? text : '',
      faces: faces ? this.faces : const <DetectedFace>[],
    );
  }

  @override
  void dispose() => disposed = true;
}
