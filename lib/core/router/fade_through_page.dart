import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_motion.dart';

/// A quiet fade-through transition for routes pushed outside the bottom-nav
/// shell: the incoming page fades in while scaling up from 96%, and the page
/// it covers fades out while scaling down to 96%. Flutter drives each
/// route's own [secondaryAnimation] for the "covered" half automatically, so
/// every route built with this helper gets both halves for free. Shell tab
/// switches stay instant via [StatefulShellRoute.indexedStack] and are not
/// touched by this helper.
///
/// Duration is resolved once at page-build time via [AppMotion.of], so
/// reduced motion collapses the whole flight to zero rather than pausing on
/// an unanimated page for [base].
///
/// [base] defaults to [AppMotion.medium]; the photo detail route passes
/// [AppMotion.long] instead, since its [Hero] flight reads best with more
/// room to travel than a plain screen swap.
/// A transition for full-screen media routes (photo detail, memory player)
/// whose [Hero] flight *is* the animation. The page is **opaque from the first
/// frame** and neither fades nor scales — [fadeThroughPage]'s fade (partial
/// opacity) and 0.96 scale both let the lighter shell beneath bleed through
/// *around and behind* the flying photo, which reads as a white border/flash on
/// open and close. Returning the child untouched leaves the black scaffold
/// covering the shell while the Hero (drawn in the app overlay, above the page)
/// carries the motion. The route's [transitionDuration] still sets how long the
/// Hero has to travel, so reduced motion (duration zero) collapses it to a cut.
CustomTransitionPage<T> heroMediaPage<T>({
  required BuildContext context,
  required LocalKey key,
  required Widget child,
  Duration base = AppMotion.long,
}) {
  final duration = AppMotion.of(context, base);
  return CustomTransitionPage<T>(
    key: key,
    child: child,
    transitionDuration: duration,
    reverseTransitionDuration: duration,
    transitionsBuilder: (context, animation, secondaryAnimation, child) =>
        child,
  );
}

CustomTransitionPage<T> fadeThroughPage<T>({
  required BuildContext context,
  required LocalKey key,
  required Widget child,
  Duration base = AppMotion.medium,
}) {
  final duration = AppMotion.of(context, base);
  return CustomTransitionPage<T>(
    key: key,
    child: child,
    transitionDuration: duration,
    reverseTransitionDuration: duration,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final entering = CurvedAnimation(
        parent: animation,
        curve: AppMotion.curve,
      );
      final covered = CurvedAnimation(
        parent: secondaryAnimation,
        curve: AppMotion.curve,
      );
      return FadeTransition(
        opacity: entering,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1).animate(entering),
          child: FadeTransition(
            opacity: Tween<double>(begin: 1, end: 0).animate(covered),
            child: ScaleTransition(
              scale: Tween<double>(begin: 1, end: 0.96).animate(covered),
              child: child,
            ),
          ),
        ),
      );
    },
  );
}
