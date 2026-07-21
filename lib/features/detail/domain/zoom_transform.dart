import 'package:vector_math/vector_math_64.dart';

/// The scale a double-tap zooms to. `InteractiveViewer`'s own `maxScale` stays
/// higher, so a pinch can still go further than one double-tap gets you.
const double kDoubleTapZoomScale = 2.0;

/// The transform that scales by [scale] about the viewport point
/// ([focalX], [focalY]), so whatever pixel sat under the finger stays under it.
///
/// Composed as `translate(-focal * (scale - 1)) · scale`: a child point `x`
/// lands at `scale * x - focal * (scale - 1)`, which is `focal` itself when
/// `x == focal`.
///
/// **Boundary assumption:** the resulting translation is
/// `-focal * (scale - 1)`, so for a focal point inside a viewport of size
/// `edge` it stays within `[-(scale - 1) * edge, 0]` — exactly the range
/// `InteractiveViewer` permits under its default `boundaryMargin` of
/// [EdgeInsets.zero], *given the child is viewport-sized*. `PhotoPage` satisfies
/// that (its `Image.memory` is `width`/`height` infinity with
/// `BoxFit.contain`, so the widget fills the viewport and letterboxes inside
/// itself). Assigning a `TransformationController` directly bypasses
/// `InteractiveViewer`'s clamping — it will not correct an out-of-bounds matrix
/// until the next gesture — so if that layout ever changes, this needs a clamp.
Matrix4 zoomedAt(double focalX, double focalY, {required double scale}) {
  final offset = scale - 1;
  return Matrix4.identity()
    ..translateByDouble(-focalX * offset, -focalY * offset, 0.0, 1.0)
    ..scaleByDouble(scale, scale, scale, 1.0);
}
