import 'dart:async';
import 'dart:io' show File;
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' show Rect, RootIsolateToken;

import 'package:flutter/services.dart'
    show BackgroundIsolateBinaryMessenger, rootBundle;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:logging/logging.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

/// One image label: the ML Kit tag text and the model's confidence in `[0, 1]`.
typedef Label = (String label, double confidence);

/// One detected face: its bounding box (in the analyzed thumbnail's pixel
/// coordinates) and its embedding vector.
typedef DetectedFace = ({
  int left,
  int top,
  int right,
  int bottom,
  Float32List embedding,
});

/// The on-device analysis of one image: labels, recognized (OCR) text, faces.
typedef ImageAnalysis = ({
  List<Label> labels,
  String text,
  List<DetectedFace> faces,
});

/// Path to the bundled MobileFaceNet model (runs fully on-device via tflite).
const _faceModelAsset = 'assets/models/mobilefacenet.tflite';

/// Runs on-device image analysis (labels + OCR + face embeddings). An interface
/// so the background-isolate implementation can be swapped for a fake in host
/// tests (CLAUDE.md fake-pairing rule — the real path is covered by an on-device
/// integration test).
abstract class MlWorker {
  /// Analyzes the image at [jpegPath] (a downsized JPEG — never an original).
  Future<ImageAnalysis> analyzeFile(String jpegPath);

  /// Tears down the worker isolate and its models.
  void dispose();
}

/// [MlWorker] backed by a long-lived background isolate running ML Kit's
/// **bundled** image-labeling, Latin text-recognition, and face-detection models
/// plus a bundled MobileFaceNet tflite embedder (no network — Absolute rule).
/// All ML runs off the UI isolate (Absolute rule). The isolate initializes the
/// plugin binary messenger *before* any ML Kit call (the isolate-binding-hang
/// gotcha); tflite is FFI and needs no messenger.
class MlWorkerController implements MlWorker {
  MlWorkerController();

  static final _log = Logger('SoloGallery.ml');

  Isolate? _isolate;
  SendPort? _commands;
  ReceivePort? _fromWorker;
  Completer<void>? _starting;
  final Map<int, Completer<ImageAnalysis>> _pending = {};
  int _seq = 0;

  Future<void> _start() {
    if (_commands != null) return Future.value();
    final existing = _starting;
    if (existing != null) return existing.future;

    final starting = _starting = Completer<void>();
    final token = RootIsolateToken.instance;
    if (token == null) {
      starting.completeError(
        StateError('MlWorkerController must be created on the root isolate.'),
      );
      return starting.future;
    }
    final receive = _fromWorker = ReceivePort()..listen(_onMessage);
    unawaited(_spawn(starting, receive.sendPort, token));
    return starting.future;
  }

  Future<void> _spawn(
    Completer<void> starting,
    SendPort replyTo,
    RootIsolateToken token,
  ) async {
    try {
      // Load the tflite model on the main isolate (rootBundle needs the root
      // binding) and hand its bytes to the worker.
      final model = await rootBundle.load(_faceModelAsset);
      final modelBytes = model.buffer.asUint8List(
        model.offsetInBytes,
        model.lengthInBytes,
      );
      _isolate = await Isolate.spawn(
        _workerMain,
        _WorkerInit(replyTo, token, modelBytes),
      );
    } catch (e, st) {
      _log.severe('Failed to spawn ML worker isolate', e, st);
      if (!starting.isCompleted) starting.completeError(e, st);
    }
  }

  void _onMessage(dynamic msg) {
    if (msg is SendPort) {
      _commands = msg;
      _starting?.complete();
      return;
    }
    if (msg is _AnalyzeResult) {
      _pending
          .remove(msg.id)
          ?.complete((labels: msg.labels, text: msg.text, faces: msg.faces));
    } else if (msg is _AnalyzeError) {
      _pending.remove(msg.id)?.completeError(StateError(msg.error));
    }
  }

  @override
  Future<ImageAnalysis> analyzeFile(String jpegPath) async {
    await _start();
    final id = _seq++;
    final completer = Completer<ImageAnalysis>();
    _pending[id] = completer;
    _commands!.send(_AnalyzeJob(id, jpegPath));
    return completer.future;
  }

  @override
  void dispose() {
    _isolate?.kill(priority: Isolate.immediate);
    _fromWorker?.close();
    _isolate = null;
    _commands = null;
    _starting = null;
    for (final c in _pending.values) {
      if (!c.isCompleted) c.completeError(StateError('ML worker disposed'));
    }
    _pending.clear();
  }
}

/// Worker-isolate entrypoint: bind the plugin messenger, build the models, then
/// serve analysis jobs.
void _workerMain(_WorkerInit init) {
  // Must run before any plugin (ML Kit) call, or platform-channel calls hang.
  BackgroundIsolateBinaryMessenger.ensureInitialized(init.token);

  final labeler = ImageLabeler(
    options: ImageLabelerOptions(confidenceThreshold: 0.6),
  );
  final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  final faceDetector = FaceDetector(options: FaceDetectorOptions());
  final embedder = Interpreter.fromBuffer(init.modelBytes);
  final embeddingSize = embedder.getOutputTensor(0).shape.last;

  final commands = ReceivePort();
  init.sendPort.send(commands.sendPort);

  commands.listen((dynamic msg) async {
    if (msg is _AnalyzeJob) {
      try {
        final input = InputImage.fromFilePath(msg.path);
        final labels = await labeler.processImage(input);
        final recognized = await recognizer.processImage(input);
        final text = recognized.text.replaceAll(RegExp(r'\s+'), ' ').trim();
        final detected = await faceDetector.processImage(input);

        final faces = <DetectedFace>[];
        if (detected.isNotEmpty) {
          final decoded = img.decodeImage(File(msg.path).readAsBytesSync());
          if (decoded != null) {
            for (final face in detected) {
              final f =
                  _embedFace(decoded, face.boundingBox, embedder, embeddingSize);
              if (f != null) faces.add(f);
            }
          }
        }

        init.sendPort.send(
          _AnalyzeResult(
            msg.id,
            [for (final l in labels) (l.label, l.confidence)],
            text,
            faces,
          ),
        );
      } catch (e) {
        init.sendPort.send(_AnalyzeError(msg.id, e.toString()));
      }
    }
  });
}

/// Crops [box] from [image], resizes to the model's 112×112 input, and returns
/// the MobileFaceNet embedding. Null if the box is degenerate.
DetectedFace? _embedFace(
  img.Image image,
  Rect box,
  Interpreter embedder,
  int embeddingSize,
) {
  final x = box.left.round().clamp(0, image.width - 1);
  final y = box.top.round().clamp(0, image.height - 1);
  final w = box.width.round().clamp(1, image.width - x);
  final h = box.height.round().clamp(1, image.height - y);
  if (w < 2 || h < 2) return null;

  final crop = img.copyResize(
    img.copyCrop(image, x: x, y: y, width: w, height: h),
    width: 112,
    height: 112,
  );

  // Input tensor [1, 112, 112, 3], normalized to ~[-1, 1] (MobileFaceNet).
  final input = List.generate(
    1,
    (_) => List.generate(
      112,
      (py) => List.generate(112, (px) {
        final p = crop.getPixel(px, py);
        return [
          (p.r - 127.5) / 128.0,
          (p.g - 127.5) / 128.0,
          (p.b - 127.5) / 128.0,
        ];
      }),
    ),
  );
  final output = List.generate(1, (_) => List.filled(embeddingSize, 0.0));
  embedder.run(input, output);

  return (
    left: x,
    top: y,
    right: x + w,
    bottom: y + h,
    embedding: Float32List.fromList(output[0].cast<double>()),
  );
}

/// Spawn payload: reply port, plugin-binding token, and the tflite model bytes.
class _WorkerInit {
  const _WorkerInit(this.sendPort, this.token, this.modelBytes);
  final SendPort sendPort;
  final RootIsolateToken token;
  final Uint8List modelBytes;
}

class _AnalyzeJob {
  const _AnalyzeJob(this.id, this.path);
  final int id;
  final String path;
}

class _AnalyzeResult {
  const _AnalyzeResult(this.id, this.labels, this.text, this.faces);
  final int id;
  final List<Label> labels;
  final String text;
  final List<DetectedFace> faces;
}

class _AnalyzeError {
  const _AnalyzeError(this.id, this.error);
  final int id;
  final String error;
}
