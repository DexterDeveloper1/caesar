import 'package:flutter/foundation.dart';

enum GameStatus { playing, gameOver }

/// Immutable snapshot of a game session, rendered by the UI.
@immutable
class GameState {
  final String prompt;
  final int score;
  final int strikes;
  final int difficulty;
  final int timeLeft;
  final GameStatus status;

  const GameState({
    required this.prompt,
    required this.score,
    required this.strikes,
    required this.difficulty,
    required this.timeLeft,
    required this.status,
  });

  bool get isGameOver => status == GameStatus.gameOver;

  GameState copyWith({
    String? prompt,
    int? score,
    int? strikes,
    int? difficulty,
    int? timeLeft,
    GameStatus? status,
  }) {
    return GameState(
      prompt: prompt ?? this.prompt,
      score: score ?? this.score,
      strikes: strikes ?? this.strikes,
      difficulty: difficulty ?? this.difficulty,
      timeLeft: timeLeft ?? this.timeLeft,
      status: status ?? this.status,
    );
  }
}
