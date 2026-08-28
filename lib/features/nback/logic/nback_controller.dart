import 'dart:async';
import 'dart:math';

import 'package:caesar/core/training_mode.dart';
import 'package:caesar/features/highscores/state/highscores_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'nback_audio.dart';
import 'nback_logic.dart';
import 'nback_state.dart';

/// Drives a Dual N-Back session: on each trial it lights a grid cell and speaks
/// a letter, collects the player's per-channel "match" responses, then scores
/// the trial. Match detection and scoring live in [nback_logic]; this class
/// owns only the timing and wiring.
class NBackController extends Notifier<NBackState> {
  final Random _rng;

  NBackController({Random? rng}) : _rng = rng ?? Random();

  static const int n = 2;
  static const int totalTrials = 20 + n;
  static const int gridSize = 9;
  static const List<String> letters = ['C', 'H', 'K', 'L', 'Q', 'R', 'S', 'T'];
  static const Duration stimulusOn = Duration(milliseconds: 2500);
  static const Duration gap = Duration(milliseconds: 500);

  late List<int> _positions;
  late List<int> _letterIndices;

  Timer? _timer;
  bool _disposed = false;
  int _generation = 0;

  NBackAudio get _speaker => ref.read(nbackAudioProvider);

  @override
  NBackState build() {
    ref.onDispose(() {
      _disposed = true;
      _timer?.cancel();
    });
    _generateSequences();
    _generation++;
    scheduleMicrotask(() => _startTrial(_generation));
    return const NBackState.initial(n: n, totalTrials: totalTrials);
  }

  void _generateSequences() {
    _positions = List.generate(totalTrials, (_) => _rng.nextInt(gridSize));
    _letterIndices = List.generate(
      totalTrials,
      (_) => _rng.nextInt(letters.length),
    );
  }

  void _startTrial(int generation) {
    if (_disposed || generation != _generation) return;
    final i = state.trialIndex;
    state = state.copyWith(
      activeCell: _positions[i],
      positionPressed: false,
      audioPressed: false,
    );
    unawaited(_speaker.speakLetter(letters[_letterIndices[i]]));
    _timer = Timer(stimulusOn, () => _resolveTrial(generation));
  }

  void pressPosition() {
    if (!state.isRunning || state.activeCell == null) return;
    if (!state.positionPressed) state = state.copyWith(positionPressed: true);
  }

  void pressAudio() {
    if (!state.isRunning || state.activeCell == null) return;
    if (!state.audioPressed) state = state.copyWith(audioPressed: true);
  }

  void _resolveTrial(int generation) {
    if (_disposed || generation != _generation) return;
    final i = state.trialIndex;

    final positionOutcome = classifyResponse(
      isMatch: isNBackMatch(_positions, i, n),
      pressed: state.positionPressed,
    );
    final audioOutcome = classifyResponse(
      isMatch: isNBackMatch(_letterIndices, i, n),
      pressed: state.audioPressed,
    );

    final scored = state.copyWith(
      position: state.position.record(positionOutcome),
      audio: state.audio.record(audioOutcome),
      clearActiveCell: true,
    );

    final nextIndex = i + 1;
    if (nextIndex >= totalTrials) {
      state = scored.copyWith(
        trialIndex: nextIndex,
        status: NBackStatus.finished,
      );
      ref
          .read(highscoresControllerProvider.notifier)
          .submit(TrainingMode.nback, state.score);
    } else {
      state = scored.copyWith(trialIndex: nextIndex);
      _timer = Timer(gap, () => _startTrial(generation));
    }
  }

  void restart() {
    _timer?.cancel();
    _generateSequences();
    _generation++;
    state = const NBackState.initial(n: n, totalTrials: totalTrials);
    scheduleMicrotask(() => _startTrial(_generation));
  }
}

final nbackControllerProvider =
    NotifierProvider.autoDispose<NBackController, NBackState>(
      NBackController.new,
    );
