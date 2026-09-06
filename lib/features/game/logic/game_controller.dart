import 'dart:async';

import 'package:caesar/core/constants.dart';
import 'package:caesar/core/training_mode.dart';
import 'package:caesar/features/highscores/state/highscores_controller.dart';
import 'package:caesar/features/settings/state/settings_controller.dart';
import 'package:caesar/features/stats/state/stats_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'game_state.dart';
import 'game_type.dart';
import 'progression.dart';
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
  Timer? _revealTimer;
  String _answer = '';

  /// What replaces the word once the flash ends (spelling only).
  String _maskedPrompt = '';

  /// Skill level plus the streak that earns the next one.
  Progression _progression = const Progression();

  @override
  GameState build() {
    ref.onDispose(() {
      _timer?.cancel();
      _revealTimer?.cancel();
    });
    final startDifficulty = ref
        .read(settingsControllerProvider)
        .startDifficulty;
    _progression = Progression(level: startDifficulty);
    final initial = _nextRound(
      score: 0,
      strikes: 0,
      difficulty: _progression.level,
    );
    // The notifier's state is not assignable until build() returns, so kick the
    // round off once it has.
    scheduleMicrotask(_beginRound);
    return initial;
  }

  GameState _nextRound({
    required int score,
    required int strikes,
    required int difficulty,
  }) {
    final question = _generator.generate(_mode, difficulty);
    _answer = question.answer;
    _maskedPrompt = question.prompt;
    final allotted = QuestionGenerator.answerSeconds(_mode, difficulty);

    return GameState(
      // During a reveal the word itself is on screen; otherwise the prompt is.
      prompt: question.reveal ?? question.prompt,
      score: score,
      strikes: strikes,
      difficulty: difficulty,
      timeLeft: allotted,
      totalTime: allotted,
      revealing: question.hasRevealPhase,
      status: GameStatus.playing,
    );
  }

  /// Begins the round: flash the word first when there is one, otherwise start
  /// the clock immediately.
  void _beginRound() {
    _revealTimer?.cancel();
    if (!state.revealing) {
      _startTimer();
      return;
    }
    _timer?.cancel();
    _revealTimer = Timer(
      Duration(milliseconds: QuestionGenerator.revealMillis(state.difficulty)),
      () {
        // Hide the word and only then start the countdown, so memorising time
        // is not also answering time.
        state = state.copyWith(prompt: _maskedPrompt, revealing: false);
        _startTimer();
      },
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
    if (state.isGameOver || state.revealing) return;
    final correct = input.trim().toLowerCase() == _answer.toLowerCase();
    if (correct) {
      _progression = applyAnswer(_progression, correct: true);
      state = _nextRound(
        score: state.score + 1,
        strikes: state.strikes,
        difficulty: _progression.level,
      );
      _beginRound();
    } else {
      _registerFailure();
    }
  }

  void _registerFailure() {
    final strikes = state.strikes + 1;
    if (strikes >= GameConfig.maxStrikes) {
      _timer?.cancel();
      _revealTimer?.cancel();
      state = state.copyWith(strikes: strikes, status: GameStatus.gameOver);
      final trainingMode = _mode == GameType.math
          ? TrainingMode.math
          : TrainingMode.spelling;
      ref
          .read(highscoresControllerProvider.notifier)
          .submit(trainingMode, state.score);
      ref.read(statsControllerProvider.notifier).recordSession();
    } else {
      _progression = applyAnswer(_progression, correct: false);
      state = _nextRound(
        score: state.score,
        strikes: strikes,
        difficulty: _progression.level,
      );
      _beginRound();
    }
  }

  void restart() {
    final startDifficulty = ref
        .read(settingsControllerProvider)
        .startDifficulty;
    _progression = Progression(level: startDifficulty);
    state = _nextRound(score: 0, strikes: 0, difficulty: _progression.level);
    _beginRound();
  }
}

final gameControllerProvider = NotifierProvider.autoDispose
    .family<GameController, GameState, GameType>(GameController.new);
