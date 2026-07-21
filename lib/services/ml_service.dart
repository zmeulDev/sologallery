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

/// One detected face: its bounding box and its embedding vector.
///
/// The box is **normalized to `[0, 1]`** against the analyzed image's real
/// decoded size, so it stays meaningful without carrying those dimensions
/// around (see the `FaceEmbeddings` table docs for why pixels didn't).
typedef DetectedFace = ({
  double left,
  double top,
  double right,
  double bottom,
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
  /// Analyzes the image at [jpegPath] (a downsized JPEG — never an original) for
  /// labels and faces. When [ocrPath] is given, OCR runs on that (larger)
  /// image instead, recovering small text the face/label thumbnail misses;
  /// otherwise OCR uses [jpegPath].
  ///
  /// [content] and [faces] are the user's consent flags (both opt-in, off by
  /// default). When one is false the corresponding model never runs and its
  /// result comes back empty — the caller must not have to filter it out
  /// afterwards. With both false there is nothing to do; callers should skip
  /// the call entirely rather than pay the thumbnail write.
  Future<ImageAnalysis> analyzeFile(
    String jpegPath, {
    String? ocrPath,
    bool content = true,
    bool faces = true,
  });

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
  Future<ImageAnalysis> analyzeFile(
    String jpegPath, {
    String? ocrPath,
    bool content = true,
    bool faces = true,
  }) async {
    await _start();
    final id = _seq++;
    final completer = Completer<ImageAnalysis>();
    _pending[id] = completer;
    _commands!.send(_AnalyzeJob(id, jpegPath, ocrPath, content, faces));
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

  // Every model is opt-in, so each is built on the first job that actually asks
  // for it — a user who declined a feature never pays its model load.
  ImageLabeler? labeler;
  TextRecognizer? recognizer;
  FaceDetector? faceDetector;
  Interpreter? embedder;
  var embeddingSize = 0;

  final commands = ReceivePort();
  init.sendPort.send(commands.sendPort);

  commands.listen((dynamic msg) async {
    if (msg is _AnalyzeJob) {
      try {
        final input = InputImage.fromFilePath(msg.path);

        var labels = const <ImageLabel>[];
        var text = '';
        if (msg.content) {
          labels = await (labeler ??= ImageLabeler(
            options: ImageLabelerOptions(confidenceThreshold: 0.6),
          )).processImage(input);
          // OCR on the higher-res image when supplied (small-text recall);
          // labels and faces stay on the 512 thumbnail (bounded memory, stable
          // box space).
          final ocrInput = msg.ocrPath != null
              ? InputImage.fromFilePath(msg.ocrPath!)
              : input;
          final recognized = await (recognizer ??= TextRecognizer(
            script: TextRecognitionScript.latin,
          )).processImage(ocrInput);
          text = recognized.text.replaceAll(RegExp(r'\s+'), ' ').trim();
        }

        final faces = <DetectedFace>[];
        if (msg.faces) {
          // Landmarks on, performance mode deliberately left at `fast`. See
          // [faceIsUsable] for why `accurate` is not worth it despite reporting
          // fewer false positives: it returns different (tighter) boxes, and the
          // crop those produce embeds badly enough to undo the clustering.
          final detector = faceDetector ??= FaceDetector(
            options: FaceDetectorOptions(enableLandmarks: true),
          );
          final interpreter = embedder ??= Interpreter.fromBuffer(
            init.modelBytes,
          );
          if (embeddingSize == 0) {
            embeddingSize = interpreter.getOutputTensor(0).shape.last;
          }
          // Drop unusable detections before anything else: the gate is free
          // compared with decoding the thumbnail, so a photo whose only "faces"
          // are a dog and a passer-by in profile costs nothing more.
          final detected = [
            for (final face in await detector.processImage(input))
              if (faceIsUsable(
                yawDegrees: face.headEulerAngleY,
                rollDegrees: face.headEulerAngleZ,
                hasLeftEye: face.landmarks[FaceLandmarkType.leftEye] != null,
                hasRightEye: face.landmarks[FaceLandmarkType.rightEye] != null,
                hasNoseBase: face.landmarks[FaceLandmarkType.noseBase] != null,
              ))
                face,
          ];
          // Decoding the whole thumbnail is the expensive part, so it only
          // happens when there is actually a face to crop out of it.
          if (detected.isNotEmpty) {
            final decoded = img.decodeImage(File(msg.path).readAsBytesSync());
            if (decoded != null) {
              for (final face in detected) {
                final f = _embedFace(
                  decoded,
                  face.boundingBox,
                  interpreter,
                  embeddingSize,
                );
                if (f != null) faces.add(f);
              }
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

/// The smallest face worth keeping, as a fraction of the image's **short**
/// edge. Below this the crop is a smear of pixels: the embedding is noise, so
/// clustering can't group it and every such face becomes its own one-photo
/// "person" flooding the People grid. Measured against the short edge so the
/// threshold means the same thing in portrait and landscape.
///
/// Deliberately still 0.05. Raising it to 0.08 was proposed to clear the last
/// small junk detections, but measuring the real library killed that: the
/// surviving junk boxes are ~4% of the image width and the smallest *genuine*
/// faces are 6–7%, which is not enough separation to cut between — especially
/// as the two are measured against different edges depending on orientation.
const minFaceFraction = 0.05;

/// Whether a `w`×`h` face box in an `imageWidth`×`imageHeight` image is big
/// enough to embed — see [minFaceFraction]. Pure, so the threshold is testable
/// without running the detector.
bool faceIsLargeEnough({
  required int w,
  required int h,
  required int imageWidth,
  required int imageHeight,
}) {
  if (w < 2 || h < 2) return false;
  final shortEdge = imageWidth < imageHeight ? imageWidth : imageHeight;
  final min = shortEdge * minFaceFraction;
  return w >= min && h >= min;
}

/// Largest head turn away from the camera (degrees, ML Kit's Euler Y) still
/// worth embedding. Past this only one side of the face is visible, and
/// MobileFaceNet — which compares frontal crops — reads the result as a
/// stranger, so profiles cluster with each other rather than with the people
/// they belong to.
///
/// 35° is measured, not guessed: re-detecting a real library's stored faces, the
/// most frontal *profile* in the junk cluster sat at 42° and the most turned
/// genuine face of the most-photographed person at 32°. This is the middle of
/// that gap.
const maxFaceYaw = 35.0;

/// Largest in-plane head tilt (degrees, ML Kit's Euler Z) still worth
/// embedding. The crop is axis-aligned and unrotated, so a strongly tilted face
/// arrives at the model rotated, which it has no invariance to. On the measured
/// library every rejection was already caught by [maxFaceYaw] (worst genuine
/// tilt: 20°), so this only guards a case that library happens not to contain.
const maxFaceRoll = 25.0;

/// Whether a detection is a usable, roughly frontal human face.
///
/// **Pose is what this gate is for.** Profiles are what poisoned clustering: a
/// face turned past [maxFaceYaw] does not match its own person and instead
/// pools with every other profile in the library into one meaningless cluster.
///
/// The landmark requirement is a cheap precondition rather than the filter that
/// does the work — the same anchors Phase 3 needs to align a crop. What actually
/// removed the dog faces, the drawn face and the beer glass was moving the
/// detector to [FaceDetectorMode.accurate]: those were `fast`-mode false
/// positives and `accurate` does not report them at all. Do not conclude from
/// this that the landmark check is redundant without re-measuring; it costs
/// nothing and it is what makes an unlandmarked detection unusable rather than
/// silently mis-cropped.
///
/// Pure, so the thresholds are testable without running the detector. Null
/// angles mean the detector could not determine the pose, which is itself a
/// sign the detection is not a clean face.
bool faceIsUsable({
  required double? yawDegrees,
  required double? rollDegrees,
  required bool hasLeftEye,
  required bool hasRightEye,
  required bool hasNoseBase,
}) {
  if (!hasLeftEye || !hasRightEye || !hasNoseBase) return false;
  if (yawDegrees == null || rollDegrees == null) return false;
  return yawDegrees.abs() <= maxFaceYaw && rollDegrees.abs() <= maxFaceRoll;
}

/// Crops [box] from [image], resizes to the model's 112×112 input, and returns
/// the MobileFaceNet embedding with the box normalized to `[0, 1]`. Null if the
/// box is degenerate or too small ([faceIsLargeEnough]).
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
  if (!faceIsLargeEnough(
    w: w,
    h: h,
    imageWidth: image.width,
    imageHeight: image.height,
  )) {
    return null;
  }

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

  // Normalize against the image actually analyzed — the one place its true
  // size is known, so nothing downstream has to reconstruct it.
  final iw = image.width.toDouble();
  final ih = image.height.toDouble();
  return (
    left: x / iw,
    top: y / ih,
    right: (x + w) / iw,
    bottom: (y + h) / ih,
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
  const _AnalyzeJob(this.id, this.path, this.ocrPath, this.content, this.faces);
  final int id;
  final String path;

  /// Optional higher-res image for OCR only; null falls back to [path].
  final String? ocrPath;

  /// Whether to run labeling + OCR for this job (user consent).
  final bool content;

  /// Whether to run face detection + embedding for this job (user consent).
  final bool faces;
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
