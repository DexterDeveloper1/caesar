import 'dart:math';

import 'sudoku_generator.dart';

/// Turns a finished puzzle into a single "higher is better" number.
///
/// Sudoku is naturally scored by *time* (lower is better), which is the
/// opposite of every other mode and of the leaderboard. Converting to points —
/// a difficulty-based budget that time and mistakes eat into — keeps one
/// consistent scoring direction across the whole app.
int sudokuScore({
  required SudokuDifficulty difficulty,
  required int seconds,
  required int mistakes,
}) {
  final budget = switch (difficulty) {
    SudokuDifficulty.easy => 600,
    SudokuDifficulty.medium => 900,
    SudokuDifficulty.hard => 1200,
    SudokuDifficulty.expert => 1500,
  };
  // One point per second taken, 30 per wrong entry.
  return max(0, budget - seconds - mistakes * 30);
}
