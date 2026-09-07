import 'package:caesar/core/training_mode.dart';
import 'package:caesar/features/reader/logic/reader_document.dart';
import 'package:caesar/features/settings/state/settings_controller.dart';
import 'package:caesar/features/stats/logic/streak_logic.dart';
import 'package:caesar/features/vocabulary/logic/saved_word.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Thin, synchronous wrapper over [SharedPreferences] for the app's persisted
/// data (settings + highscores). Reads are synchronous because the underlying
/// [SharedPreferences] instance is loaded once at startup and injected.
class StorageService {
  final SharedPreferences _prefs;

  StorageService(this._prefs);

  static const _kSound = 'settings.soundEnabled';
  static const _kMusic = 'settings.musicEnabled';
  static const _kThemeMode = 'settings.themeMode';
  static const _kStartDifficulty = 'settings.startDifficulty';
  static const _kMusicWhileReading = 'settings.musicWhileReading';
  static const _kStreak = 'stats.currentStreak';
  static const _kBestStreak = 'stats.bestStreak';
  static const _kGamesPlayed = 'stats.gamesPlayed';
  static const _kLastPlayed = 'stats.lastPlayed';
  static const _kSavedWords = 'vocabulary.savedWords';
  static const _kLibrary = 'reader.library';
  static const _kReaderFontSize = 'reader.fontSize';
  static const _kDeviceId = 'account.deviceId';
  static const _kDisplayName = 'account.displayName';
  static String _highscoreKey(TrainingMode mode) => 'highscore.${mode.name}';

  Settings readSettings() {
    return Settings(
      soundEnabled: _prefs.getBool(_kSound) ?? true,
      musicEnabled: _prefs.getBool(_kMusic) ?? true,
      themeMode: ThemeMode
          .values[_prefs.getInt(_kThemeMode) ?? ThemeMode.system.index],
      startDifficulty: _prefs.getInt(_kStartDifficulty) ?? 1,
      musicWhileReading: _prefs.getBool(_kMusicWhileReading) ?? false,
    );
  }

  Future<void> writeSettings(Settings settings) async {
    await _prefs.setBool(_kSound, settings.soundEnabled);
    await _prefs.setBool(_kMusic, settings.musicEnabled);
    await _prefs.setInt(_kThemeMode, settings.themeMode.index);
    await _prefs.setInt(_kStartDifficulty, settings.startDifficulty);
    await _prefs.setBool(_kMusicWhileReading, settings.musicWhileReading);
  }

  String? readDeviceId() => _prefs.getString(_kDeviceId);

  Future<void> writeDeviceId(String id) => _prefs.setString(_kDeviceId, id);

  String? readDisplayName() => _prefs.getString(_kDisplayName);

  Future<void> writeDisplayName(String name) =>
      _prefs.setString(_kDisplayName, name);

  SavedWords readSavedWords() =>
      SavedWords.decode(_prefs.getString(_kSavedWords)).pruned();

  Future<void> writeSavedWords(SavedWords words) =>
      _prefs.setString(_kSavedWords, words.encode());

  ReaderLibrary readLibrary() =>
      ReaderLibrary.decode(_prefs.getString(_kLibrary));

  Future<void> writeLibrary(ReaderLibrary library) =>
      _prefs.setString(_kLibrary, library.encode());

  double readReaderFontSize() => _prefs.getDouble(_kReaderFontSize) ?? 19;

  Future<void> writeReaderFontSize(double size) =>
      _prefs.setDouble(_kReaderFontSize, size);

  PlayerStats readStats() {
    return PlayerStats(
      currentStreak: _prefs.getInt(_kStreak) ?? 0,
      bestStreak: _prefs.getInt(_kBestStreak) ?? 0,
      gamesPlayed: _prefs.getInt(_kGamesPlayed) ?? 0,
      lastPlayed: _prefs.getString(_kLastPlayed),
    );
  }

  Future<void> writeStats(PlayerStats stats) async {
    await _prefs.setInt(_kStreak, stats.currentStreak);
    await _prefs.setInt(_kBestStreak, stats.bestStreak);
    await _prefs.setInt(_kGamesPlayed, stats.gamesPlayed);
    final last = stats.lastPlayed;
    if (last != null) await _prefs.setString(_kLastPlayed, last);
  }

  Map<TrainingMode, int> readHighscores() {
    return {
      for (final mode in TrainingMode.values)
        mode: _prefs.getInt(_highscoreKey(mode)) ?? 0,
    };
  }

  Future<void> writeHighscore(TrainingMode mode, int score) =>
      _prefs.setInt(_highscoreKey(mode), score);
}

/// Overridden in `main()` with the real, pre-loaded instance.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) =>
      throw UnimplementedError('sharedPreferencesProvider must be overridden'),
);

final storageServiceProvider = Provider<StorageService>(
  (ref) => StorageService(ref.watch(sharedPreferencesProvider)),
);
