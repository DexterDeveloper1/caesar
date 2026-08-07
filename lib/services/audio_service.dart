import 'package:caesar/features/settings/state/settings_controller.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Lightweight feedback for game events.
///
/// Uses the platform's built-in system sounds and haptics rather than bundled
/// audio files, so it needs no extra plugin or assets and works everywhere.
/// All feedback is a no-op when the user has disabled sound in settings.
class AudioService {
  final bool enabled;

  const AudioService({required this.enabled});

  void correct() {
    if (!enabled) return;
    SystemSound.play(SystemSoundType.click);
    HapticFeedback.lightImpact();
  }

  void wrong() {
    if (!enabled) return;
    HapticFeedback.mediumImpact();
  }

  void gameOver() {
    if (!enabled) return;
    HapticFeedback.heavyImpact();
  }
}

/// Rebuilds whenever the sound preference changes so the latest value is used.
final audioServiceProvider = Provider<AudioService>((ref) {
  final enabled = ref.watch(
    settingsControllerProvider.select((s) => s.soundEnabled),
  );
  return AudioService(enabled: enabled);
});
