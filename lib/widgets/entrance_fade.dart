import 'package:flutter/widgets.dart';

import '../core/theme/app_motion.dart';

/// Fades and rises [child] in once, the first time it's built — used for
/// section entrances (library months, onboarding rows) so a screen's first
/// paint reads as one arrival rather than instant pop-in.
///
/// Fires exactly once per mount: `_visible` only ever flips false→true, so a
/// rebuild (e.g. the section staying mounted while the user scrolls it back
/// into view) never replays it. [index] staggers the start by
/// `AppMotion.stagger * index`, clamped to [maxStaggerIndex] so a long list's
/// later items don't wait unreasonably. Under reduced motion both the
/// stagger delay and the reveal collapse to zero (via [AppMotion.of]), so the
/// child simply appears in its final position on the first frame.
///
/// Deliberately never used on grid cells — only on whole sections/rows, per
/// the no-per-cell-transforms rule (see [Pressable]'s doc).
class EntranceFade extends StatefulWidget {
  const EntranceFade({
    super.key,
    required this.child,
    this.index = 0,
    this.maxStaggerIndex = 6,
  });

  final Widget child;
  final int index;
  final int maxStaggerIndex;

  @override
  State<EntranceFade> createState() => _EntranceFadeState();
}

class _EntranceFadeState extends State<EntranceFade> {
  bool _visible = false;
  bool _scheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Guarded to run once: didChangeDependencies re-fires on any inherited
    // dependency change (e.g. theme/MediaQuery), but the entrance itself
    // must only ever be scheduled the first time.
    if (_scheduled) return;
    _scheduled = true;
    final steps = widget.index.clamp(0, widget.maxStaggerIndex);
    final delay = AppMotion.of(context, AppMotion.stagger) * steps;
    if (delay == Duration.zero) {
      // Reduced motion, or index 0: nothing to wait for — render already
      // visible on the first frame instead of scheduling a same-duration
      // delayed callback.
      _visible = true;
    } else {
      Future.delayed(delay, () {
        if (mounted) setState(() => _visible = true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: _visible ? 1 : 0),
      duration: AppMotion.of(context, AppMotion.medium),
      curve: AppMotion.curve,
      builder: (context, t, child) {
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 12),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
