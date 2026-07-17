import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'services/permission_provider.dart';

/// Root widget: wires themes and the router. Theme mode follows the system.
///
/// It also observes the app lifecycle and re-reads photo access on resume, so
/// permission revoked in system settings while the app was backgrounded is
/// picked up immediately — the router redirect then returns the user to
/// onboarding.
class SoloGalleryApp extends ConsumerStatefulWidget {
  const SoloGalleryApp({super.key});

  @override
  ConsumerState<SoloGalleryApp> createState() => _SoloGalleryAppState();
}

class _SoloGalleryAppState extends ConsumerState<SoloGalleryApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(permissionProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'SoloGallery',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
