import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:caesar/features/game/logic/game_type.dart';
import 'package:caesar/features/settings/state/settings_controller.dart';

/// Thin, synchronous wrapper over [SharedPreferences] for the app's persisted
/// data (settings + highscores). Reads are synchronous because the underlying
/// [SharedPreferences] instance is loaded once at startup and injected.
class StorageService {
  final SharedPreferences _prefs;

  StorageService(this._prefs);

  static const _kSound = 'settings.soundEnabled';
  static const _kThemeMode = 'settings.themeMode';
  static const _kStartDifficulty = 'settings.startDifficulty';
  static String _highscoreKey(GameType mode) => 'highscore.${mode.name}';

  Settings readSettings() {
    return Settings(
      soundEnabled: _prefs.getBool(_kSound) ?? true,
      themeMode:
          ThemeMode.values[_prefs.getInt(_kThemeMode) ??
              ThemeMode.system.index],
      startDifficulty: _prefs.getInt(_kStartDifficulty) ?? 1,
    );
  }

  Future<void> writeSettings(Settings settings) async {
    await _prefs.setBool(_kSound, settings.soundEnabled);
    await _prefs.setInt(_kThemeMode, settings.themeMode.index);
    await _prefs.setInt(_kStartDifficulty, settings.startDifficulty);
  }

  Map<GameType, int> readHighscores() {
    return {
      for (final mode in GameType.values)
        mode: _prefs.getInt(_highscoreKey(mode)) ?? 0,
    };
  }

  Future<void> writeHighscore(GameType mode, int score) =>
      _prefs.setInt(_highscoreKey(mode), score);
}

/// Overridden in `main()` with the real, pre-loaded instance.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider must be overridden'),
);

final storageServiceProvider = Provider<StorageService>(
  (ref) => StorageService(ref.watch(sharedPreferencesProvider)),
);
