import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/settings/theme_mode_provider.dart';
import 'services/indexing_service.dart';
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
    // Kick indexing if access was already granted on a warm start (the
    // permission listener below only fires on a *change* to granted).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(permissionProvider).canReadLibrary) {
        ref.read(indexingServiceProvider).start();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        ref.read(permissionProvider.notifier).refresh();
        ref.read(indexingServiceProvider).resume();
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        // Defer all indexing work while the app isn't in the foreground.
        ref.read(indexingServiceProvider).pause();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Start indexing when access transitions to granted (onboarding grant path).
    ref.listen(permissionProvider, (_, next) {
      if (next.canReadLibrary) ref.read(indexingServiceProvider).start();
    });
    final router = ref.watch(routerProvider);
    // Persisted theme override (Settings); defaults to system until it loads.
    final themeMode =
        ref.watch(themeModeProvider).value ?? ThemeMode.system;
    return MaterialApp.router(
      title: 'SoloGallery',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
