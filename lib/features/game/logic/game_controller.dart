import 'dart:async';
import 'dart:math';

import 'package:caesar/core/constants.dart';
import 'package:caesar/core/training_mode.dart';
import 'package:caesar/features/highscores/state/highscores_controller.dart';
import 'package:caesar/features/settings/state/settings_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'game_state.dart';
import 'game_type.dart';
import 'question_generator.dart';

/// Owns a single game session for a given [GameType]. All gameplay rules —
/// scoring, strikes, the countdown timer, difficulty ramp — live here rather
/// than in the widget, so they're testable and the UI stays declarative.
class GameController extends Notifier<GameState> {
  final GameType _mode;
  final QuestionGenerator _generator;

  GameController(this._mode, {QuestionGenerator? generator})
    : _generator = generator ?? QuestionGenerator();

  Timer? _timer;
  String _answer = '';

  @override
  GameState build() {
    ref.onDispose(() => _timer?.cancel());
    final startDifficulty = ref
        .read(settingsControllerProvider)
        .startDifficulty;
    final initial = _nextRound(
      score: 0,
      strikes: 0,
      difficulty: startDifficulty,
    );
    _startTimer();
    return initial;
  }

  GameState _nextRound({
    required int score,
    required int strikes,
    required int difficulty,
  }) {
    final question = _generator.generate(_mode, difficulty);
    _answer = question.answer;
    return GameState(
      prompt: question.prompt,
      score: score,
      strikes: strikes,
      difficulty: difficulty,
      timeLeft: max(5, 12 - difficulty),
      status: GameStatus.playing,
    );
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.isGameOver) return;
      final remaining = state.timeLeft - 1;
      if (remaining <= 0) {
        _registerFailure();
      } else {
        state = state.copyWith(timeLeft: remaining);
      }
    });
  }

  /// Submits the player's typed answer for the current question.
  void submit(String input) {
    if (state.isGameOver) return;
    final correct = input.trim().toLowerCase() == _answer.toLowerCase();
    if (correct) {
      state = _nextRound(
        score: state.score + 1,
        strikes: state.strikes,
        difficulty: state.difficulty + 1,
      );
    } else {
      _registerFailure();
    }
  }

  void _registerFailure() {
    final strikes = state.strikes + 1;
    if (strikes >= GameConfig.maxStrikes) {
      _timer?.cancel();
      state = state.copyWith(strikes: strikes, status: GameStatus.gameOver);
      final trainingMode = _mode == GameType.math
          ? TrainingMode.math
          : TrainingMode.spelling;
      ref
          .read(highscoresControllerProvider.notifier)
          .submit(trainingMode, state.score);
    } else {
      state = _nextRound(
        score: state.score,
        strikes: strikes,
        difficulty: state.difficulty,
      );
    }
  }

  void restart() {
    final startDifficulty = ref
        .read(settingsControllerProvider)
        .startDifficulty;
    state = _nextRound(score: 0, strikes: 0, difficulty: startDifficulty);
    _startTimer();
  }
}

final gameControllerProvider = NotifierProvider.autoDispose
    .family<GameController, GameState, GameType>(GameController.new);
