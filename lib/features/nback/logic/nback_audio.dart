import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Speaks the N-Back audio channel. Abstracted so the controller can be tested
/// without a real text-to-speech engine.
abstract class NBackAudio {
  Future<void> speakLetter(String letter);
  Future<void> dispose();
}

/// Real implementation backed by `flutter_tts`.
class TtsNBackAudio implements NBackAudio {
  final FlutterTts _tts = FlutterTts();
  bool _configured = false;

  Future<void> _ensureConfigured() async {
    if (_configured) return;
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1);
    await _tts.setPitch(1);
    _configured = true;
  }

  @override
  Future<void> speakLetter(String letter) async {
    await _ensureConfigured();
    await _tts.stop();
    await _tts.speak(letter);
  }

  @override
  Future<void> dispose() => _tts.stop();
}

final nbackAudioProvider = Provider<NBackAudio>((ref) {
  final audio = TtsNBackAudio();
  ref.onDispose(audio.dispose);
  return audio;
});
