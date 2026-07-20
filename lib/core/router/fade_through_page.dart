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
