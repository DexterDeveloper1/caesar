import 'dart:async';
import 'dart:math';

import 'package:caesar/core/training_mode.dart';
import 'package:caesar/features/highscores/state/highscores_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'simon_state.dart';

/// Number of pads on the board.
const int simonPadCount = 4;

/// The outcome of a single pad tap, independent of any timing or state
/// mutation — kept pure so it can be unit-tested directly.
enum SimonTap { correct, roundComplete, wrong }

SimonTap evaluateSimonTap(List<int> sequence, int inputIndex, int pad) {
  if (inputIndex >= sequence.length || sequence[inputIndex] != pad) {
    return SimonTap.wrong;
  }
  if (inputIndex == sequence.length - 1) return SimonTap.roundComplete;
  return SimonTap.correct;
}

/// Drives a Simon session: plays back a growing sequence, then accepts the
/// player's taps. Playback timing lives here; the pure [evaluateSimonTap]
/// decides correctness.
class SimonController extends Notifier<SimonState> {
  final Random _rng;

  SimonController({Random? rng}) : _rng = rng ?? Random();

  static const Duration flashOn = Duration(milliseconds: 450);
  static const Duration flashGap = Duration(milliseconds: 220);
  static const Duration roundPause = Duration(milliseconds: 600);

  bool _disposed = false;

  /// Guards against stale playback loops after a restart.
  int _generation = 0;

  @override
  SimonState build() {
    ref.onDispose(() => _disposed = true);
    _generation++;
    scheduleMicrotask(() => _startRound(_generation));
    return const SimonState.initial();
  }

  Future<void> _startRound(int generation) async {
    if (_disposed || generation != _generation) return;
    final next = [...state.sequence, _rng.nextInt(simonPadCount)];
    state = state.copyWith(
      sequence: next,
      inputIndex: 0,
      status: SimonStatus.showing,
      clearActivePad: true,
    );
    await _playback(next, generation);
  }

  Future<void> _playback(List<int> sequence, int generation) async {
    await Future<void>.delayed(roundPause);
    for (final pad in sequence) {
      if (_disposed || generation != _generation) return;
      state = state.copyWith(activePad: pad);
      await Future<void>.delayed(flashOn);
      if (_disposed || generation != _generation) return;
      state = state.copyWith(clearActivePad: true);
      await Future<void>.delayed(flashGap);
    }
    if (_disposed || generation != _generation) return;
    state = state.copyWith(status: SimonStatus.input, inputIndex: 0);
  }

  void onTap(int pad) {
    if (!state.acceptsInput) return;
    switch (evaluateSimonTap(state.sequence, state.inputIndex, pad)) {
      case SimonTap.correct:
        state = state.copyWith(inputIndex: state.inputIndex + 1);
      case SimonTap.roundComplete:
        state = state.copyWith(
          level: state.level + 1,
          status: SimonStatus.showing,
        );
        _generation++;
        scheduleMicrotask(() => _startRound(_generation));
      case SimonTap.wrong:
        state = state.copyWith(status: SimonStatus.gameOver);
        ref
            .read(highscoresControllerProvider.notifier)
            .submit(TrainingMode.simon, state.level);
    }
  }

  void restart() {
    _generation++;
    state = const SimonState.initial();
    scheduleMicrotask(() => _startRound(_generation));
  }
}

final simonControllerProvider =
    NotifierProvider.autoDispose<SimonController, SimonState>(
      SimonController.new,
    );
