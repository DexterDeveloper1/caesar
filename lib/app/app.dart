import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:caesar/core/constants.dart';
import 'package:caesar/features/settings/state/settings_controller.dart';
import 'router.dart';
import 'theme.dart';

class CaesarApp extends ConsumerWidget {
  const CaesarApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Rebuild only when the theme preference changes.
    final themeMode = ref.watch(
      settingsControllerProvider.select((s) => s.themeMode),
    );

    return MaterialApp.router(
      title: AppInfo.name,
      debugShowCheckedModeBanner: false,
      theme: CaesarTheme.lightTheme,
      darkTheme: CaesarTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: caesarRouter,
    );
  }
}
