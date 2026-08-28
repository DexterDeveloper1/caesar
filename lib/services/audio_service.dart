import 'package:audioplayers/audioplayers.dart';
import 'package:caesar/features/settings/state/settings_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Asset paths for every sound in the app.
///
/// Paths are relative to `assets/` because audioplayers' [AssetSource]
/// resolves against that folder. Swap these files for higher-quality audio
/// (`.ogg`/`.mp3` also work) without touching any other code.
class Sfx {
  static const correct = 'audio/correct.wav';
  static const wrong = 'audio/wrong.wav';
  static const gameOver = 'audio/game_over.wav';
  static const levelUp = 'audio/level_up.wav';
  static const tap = 'audio/tap.wav';
  static const music = 'audio/music_loop.wav';

  /// Tone for Simon pad [index] (0-3).
  static String simonPad(int index) => 'audio/simon_$index.wav';
}

/// Plays sound effects and background music.
///
/// Two independent channels:
///  * **SFX** — short one-shots, played on a small pool so overlapping sounds
///    don't cut each other off. Gated by [Settings.soundEnabled].
///  * **Music** — a single looping bed. Gated by [Settings.musicEnabled], and
///    can be temporarily ducked (see [duckMusic]) for modes where spoken audio
///    matters, such as N-Back.
///
/// Playback failures are swallowed: audio is a nice-to-have, and a missing or
/// unsupported file must never crash a game.
class AudioService {
  AudioService({required this.soundEnabled, required this.musicEnabled});

  final bool soundEnabled;
  final bool musicEnabled;

  static const int _poolSize = 4;
  final List<AudioPlayer> _sfxPool = [];
  int _next = 0;

  AudioPlayer? _musicPlayer;
  bool _musicDucked = false;

  Future<void> _safe(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      // Never let audio problems surface as app errors.
      debugPrint('AudioService: $e');
    }
  }

  AudioPlayer _nextPlayer() {
    if (_sfxPool.length < _poolSize) {
      final player = AudioPlayer()..setReleaseMode(ReleaseMode.stop);
      _sfxPool.add(player);
      return player;
    }
    final player = _sfxPool[_next];
    _next = (_next + 1) % _poolSize;
    return player;
  }

  /// Plays a one-shot effect, if sound is enabled.
  Future<void> play(String asset, {double volume = 1.0}) async {
    if (!soundEnabled) return;
    await _safe(() async {
      final player = _nextPlayer();
      await player.stop();
      await player.setVolume(volume);
      await player.play(AssetSource(asset));
    });
  }

  void correct() {
    play(Sfx.correct);
    if (soundEnabled) HapticFeedback.lightImpact();
  }

  void wrong() {
    play(Sfx.wrong);
    if (soundEnabled) HapticFeedback.mediumImpact();
  }

  void gameOver() {
    play(Sfx.gameOver);
    if (soundEnabled) HapticFeedback.heavyImpact();
  }

  void levelUp() {
    play(Sfx.levelUp);
    if (soundEnabled) HapticFeedback.lightImpact();
  }

  void tap() {
    play(Sfx.tap, volume: 0.7);
    if (soundEnabled) HapticFeedback.selectionClick();
  }

  /// Plays the tone for a Simon pad, so the sequence is heard as well as seen.
  void simonPad(int index) {
    play(Sfx.simonPad(index));
    if (soundEnabled) HapticFeedback.selectionClick();
  }

  // ------------------------------------------------------------ music

  /// Starts the looping background track (no-op if music is off or already
  /// playing).
  Future<void> startMusic() async {
    if (!musicEnabled || _musicPlayer != null) return;
    await _safe(() async {
      final player = AudioPlayer()..setReleaseMode(ReleaseMode.loop);
      await player.setVolume(_musicDucked ? 0.0 : 1.0);
      await player.play(AssetSource(Sfx.music));
      _musicPlayer = player;
    });
  }

  Future<void> stopMusic() async {
    final player = _musicPlayer;
    _musicPlayer = null;
    if (player == null) return;
    await _safe(() async {
      await player.stop();
      await player.dispose();
    });
  }

  /// Silences the music without stopping it — used while N-Back speaks letters.
  Future<void> duckMusic({required bool ducked}) async {
    _musicDucked = ducked;
    final player = _musicPlayer;
    if (player == null) return;
    await _safe(() => player.setVolume(ducked ? 0.0 : 1.0));
  }

  Future<void> dispose() async {
    for (final player in _sfxPool) {
      await _safe(player.dispose);
    }
    _sfxPool.clear();
    await stopMusic();
  }
}

/// Rebuilt whenever the sound or music preference changes.
final audioServiceProvider = Provider<AudioService>((ref) {
  final soundEnabled = ref.watch(
    settingsControllerProvider.select((s) => s.soundEnabled),
  );
  final musicEnabled = ref.watch(
    settingsControllerProvider.select((s) => s.musicEnabled),
  );
  final service = AudioService(
    soundEnabled: soundEnabled,
    musicEnabled: musicEnabled,
  );
  ref.onDispose(service.dispose);
  return service;
});
