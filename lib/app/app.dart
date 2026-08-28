import 'package:caesar/core/constants.dart';
import 'package:caesar/features/settings/state/settings_controller.dart';
import 'package:caesar/services/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';
import 'theme.dart';

class CaesarApp extends ConsumerStatefulWidget {
  const CaesarApp({super.key});

  @override
  ConsumerState<CaesarApp> createState() => _CaesarAppState();
}

class _CaesarAppState extends ConsumerState<CaesarApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Start after the first frame so the provider tree is ready.
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncMusic());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Don't keep playing music while the app is in the background.
    final audio = ref.read(audioServiceProvider);
    if (state == AppLifecycleState.resumed) {
      _syncMusic();
    } else {
      audio.stopMusic();
    }
  }

  void _syncMusic() {
    final audio = ref.read(audioServiceProvider);
    if (ref.read(settingsControllerProvider).musicEnabled) {
      audio.startMusic();
    } else {
      audio.stopMusic();
    }
  }

  @override
  Widget build(BuildContext context) {
    // React to the music toggle being flipped in Settings.
    ref.listen(settingsControllerProvider.select((s) => s.musicEnabled), (
      previous,
      next,
    ) {
      _syncMusic();
    });

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
