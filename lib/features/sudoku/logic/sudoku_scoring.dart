import 'dart:math';

import 'sudoku_generator.dart';

/// Turns a finished puzzle into a single "higher is better" number.
///
/// Sudoku is naturally scored by *time* (lower is better), the opposite of
/// every other mode and of the leaderboard, so time is converted to points.
///
/// The first version subtracted seconds from a fixed budget, which was wrong in
/// two ways. The budgets were far shorter than a real 9x9 takes, so an honest
/// solve scored **zero** — and because a highscore is only recorded when it
/// beats the previous best, zero never beat zero and the board kept reading
/// "Not played" no matter how many puzzles were finished.
///
/// Now finishing always pays [completionPoints]; speed adds a bonus on top and
/// mistakes chip away at it, but the total can never fall to nothing.
int sudokuScore({
  required SudokuDifficulty difficulty,
  required int seconds,
  required int mistakes,
}) {
  final base = difficulty.completionPoints;

  // Solving in par earns no bonus; solving instantly would roughly double the
  // score. Slower than par simply earns nothing extra — never a penalty.
  final par = difficulty.parSeconds;
  final remaining = par - seconds;
  final speedBonus = remaining <= 0 ? 0 : (remaining * base) ~/ par;

  final penalty = mistakes * difficulty.mistakePenalty;

  // Completing the puzzle is always worth something, however messy the run.
  final floor = (base * 0.25).round();
  return max(floor, base + speedBonus - penalty);
}
