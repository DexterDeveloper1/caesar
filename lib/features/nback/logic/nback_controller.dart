import 'dart:async';
import 'dart:math';

import 'package:caesar/core/training_mode.dart';
import 'package:caesar/features/highscores/state/highscores_controller.dart';
import 'package:caesar/features/stats/state/stats_controller.dart';
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

  /// Starting working-memory load; raised or lowered between sessions by
  /// [nextN] according to how the player performed.
  static const int startingN = 2;
  static const int trialsPerSession = 20;

  int _n = startingN;

  /// The first N trials can never be matches, so the session is padded to keep
  /// the number of scoreable trials constant as N changes.
  int get _totalTrials => trialsPerSession + _n;

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
    return NBackState.initial(n: _n, totalTrials: _totalTrials);
  }

  void _generateSequences() {
    // Plant a fixed number of targets rather than hoping random stimuli
    // collide — see [planTargets].
    final (positionTargets, audioTargets) = planTargets(
      trials: _totalTrials,
      n: _n,
      rng: _rng,
    );
    _positions = buildSequence(
      trials: _totalTrials,
      n: _n,
      alphabet: gridSize,
      targets: positionTargets,
      rng: _rng,
    );
    _letterIndices = buildSequence(
      trials: _totalTrials,
      n: _n,
      alphabet: letters.length,
      targets: audioTargets,
      rng: _rng,
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
      isMatch: isNBackMatch(_positions, i, _n),
      pressed: state.positionPressed,
    );
    final audioOutcome = classifyResponse(
      isMatch: isNBackMatch(_letterIndices, i, _n),
      pressed: state.audioPressed,
    );

    final scored = state.copyWith(
      position: state.position.record(positionOutcome),
      audio: state.audio.record(audioOutcome),
      clearActiveCell: true,
    );

    final nextIndex = i + 1;
    if (nextIndex >= _totalTrials) {
      state = scored.copyWith(
        trialIndex: nextIndex,
        status: NBackStatus.finished,
      );
      ref
          .read(highscoresControllerProvider.notifier)
          .submit(TrainingMode.nback, state.score);
      ref.read(statsControllerProvider.notifier).recordSession();

      // Move the difficulty toward the edge of the player's ability so the
      // next session keeps training rather than drilling.
      _n = nextN(_n, state.accuracy);
    } else {
      state = scored.copyWith(trialIndex: nextIndex);
      _timer = Timer(gap, () => _startTrial(generation));
    }
  }

  void restart() {
    _timer?.cancel();
    _generateSequences();
    _generation++;
    state = NBackState.initial(n: _n, totalTrials: _totalTrials);
    scheduleMicrotask(() => _startTrial(_generation));
  }
}

final nbackControllerProvider =
    NotifierProvider.autoDispose<NBackController, NBackState>(
      NBackController.new,
    );
