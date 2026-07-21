import 'package:flutter/widgets.dart';

import '../core/theme/app_motion.dart';

/// Pressed-state feedback for tappable cards: scales the child to 0.97 while a
/// pointer is down, springing back on release or cancel. Tap and long-press are
/// forwarded unchanged. Under the system reduced-motion setting the duration is
/// zero ([AppMotion.of]) — behavior is identical, just instant.
///
/// Adopted on cards only (AlbumCard, MemoryCard, the People card) — grid photo
/// cells deliberately stay static: a scale on a tightly packed cell reads as
/// neighbor jitter and risks the 60fps scroll guarantee.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    this.onTap,
    this.onLongPress,
    required this.child,
  });

  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget child;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    // The raw pointer drives the visual (down the instant the finger lands,
    // and held through a long-press); the GestureDetector owns the semantics
    // and gesture arena exactly as the cards' previous plain detectors did.
    return Listener(
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1,
          duration: AppMotion.of(context, AppMotion.pressed),
          curve: AppMotion.curve,
          child: widget.child,
        ),
      ),
    );
  }
}
