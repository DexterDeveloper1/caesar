import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:caesar/services/storage_service.dart';

/// User-configurable app settings, persisted via [StorageService].
@immutable
class Settings {
  final bool soundEnabled;
  final ThemeMode themeMode;
  final int startDifficulty;

  const Settings({
    this.soundEnabled = true,
    this.themeMode = ThemeMode.system,
    this.startDifficulty = 1,
  });

  Settings copyWith({
    bool? soundEnabled,
    ThemeMode? themeMode,
    int? startDifficulty,
  }) {
    return Settings(
      soundEnabled: soundEnabled ?? this.soundEnabled,
      themeMode: themeMode ?? this.themeMode,
      startDifficulty: startDifficulty ?? this.startDifficulty,
    );
  }
}

/// Loads settings from storage on build and writes through on every change.
class SettingsController extends Notifier<Settings> {
  StorageService get _storage => ref.read(storageServiceProvider);

  @override
  Settings build() => _storage.readSettings();

  void setSoundEnabled(bool value) => _update(state.copyWith(soundEnabled: value));

  void setThemeMode(ThemeMode mode) => _update(state.copyWith(themeMode: mode));

  void setStartDifficulty(int difficulty) =>
      _update(state.copyWith(startDifficulty: difficulty));

  void _update(Settings next) {
    state = next;
    _storage.writeSettings(next);
  }
}

final settingsControllerProvider =
    NotifierProvider<SettingsController, Settings>(SettingsController.new);
