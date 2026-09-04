import 'package:flutter/material.dart';

import '../../../core/theme/app_space.dart';

/// Padding shared by every Library scrollable so the floating nav capsule never
/// overlaps the last item.
EdgeInsets libraryBottomPadding(BuildContext context) => EdgeInsets.only(
      top: AppSpace.s4,
      bottom: AppSpace.s24 + MediaQuery.paddingOf(context).bottom,
    );
