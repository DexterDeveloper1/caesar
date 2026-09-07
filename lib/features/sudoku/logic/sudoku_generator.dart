import 'dart:math';

import 'package:flutter/foundation.dart';

import 'sudoku_board.dart';
import 'sudoku_solver.dart';

enum SudokuDifficulty {
  easy,
  medium,
  hard,
  expert;

  String get label => switch (this) {
    SudokuDifficulty.easy => 'Easy',
    SudokuDifficulty.medium => 'Medium',
    SudokuDifficulty.hard => 'Hard',
    SudokuDifficulty.expert => 'Expert',
  };

  /// Clues left on the board. Fewer clues means more deduction is required.
  /// The floor is 17 — the proven minimum for a uniquely solvable Sudoku.
  int get targetClues => switch (this) {
    SudokuDifficulty.easy => 45,
    SudokuDifficulty.medium => 36,
    SudokuDifficulty.hard => 30,
    SudokuDifficulty.expert => 26,
  };
}

@immutable
class SudokuPuzzle {
  /// The starting board; 0 means the player must fill it in.
  final List<int> givens;

  /// The unique solution.
  final List<int> solution;

  final SudokuDifficulty difficulty;

  const SudokuPuzzle({
    required this.givens,
    required this.solution,
    required this.difficulty,
  });

  int get clueCount => givens.where((c) => c != 0).length;
}

/// Builds a puzzle with exactly one solution.
///
/// Two phases: fill a complete grid at random, then remove clues one at a time,
/// keeping a removal only while the board still solves uniquely.
SudokuPuzzle generateSudoku(SudokuDifficulty difficulty, {Random? rng}) {
  final random = rng ?? Random();
  final solution = _fullGrid(random);
  final givens = List<int>.of(solution);

  final order = List.generate(sudokuCells, (i) => i)..shuffle(random);
  // Never go below the 17-clue minimum, whatever the difficulty asks for.
  final floor = difficulty.targetClues < 17 ? 17 : difficulty.targetClues;
  var remaining = sudokuCells;

  for (final index in order) {
    if (remaining <= floor) break;
    final removed = givens[index];
    givens[index] = 0;
    if (countSolutions(givens) == 1) {
      remaining--;
    } else {
      givens[index] = removed; // ambiguous without it — put it back
    }
  }

  return SudokuPuzzle(
    givens: List.unmodifiable(givens),
    solution: List.unmodifiable(solution),
    difficulty: difficulty,
  );
}

/// A randomly filled, fully valid grid.
List<int> _fullGrid(Random random) {
  final cells = List.filled(sudokuCells, 0);
  _fill(cells, random);
  return cells;
}

bool _fill(List<int> cells, Random random) {
  final index = cells.indexOf(0);
  if (index == -1) return true;

  final values = List.generate(sudokuSize, (i) => i + 1)..shuffle(random);
  for (final value in values) {
    if (!isValidPlacement(cells, index, value)) continue;
    cells[index] = value;
    if (_fill(cells, random)) return true;
    cells[index] = 0;
  }
  return false;
}

/// A playable session over a [SudokuPuzzle].
///
/// Immutable: each move returns a new game, which keeps it trivially testable
/// and lets the UI diff states.
@immutable
class SudokuGame {
  final SudokuPuzzle puzzle;
  final List<int> entries;

  /// Wrong values entered so far, counted once per placement.
  final int mistakes;

  const SudokuGame({
    required this.puzzle,
    required this.entries,
    required this.mistakes,
  });

  factory SudokuGame.from(SudokuPuzzle puzzle) => SudokuGame(
    puzzle: puzzle,
    entries: List.unmodifiable(puzzle.givens),
    mistakes: 0,
  );

  bool isGiven(int index) => puzzle.givens[index] != 0;

  int valueAt(int index) => entries[index];

  /// A filled cell whose value disagrees with the solution.
  bool isWrong(int index) =>
      entries[index] != 0 && entries[index] != puzzle.solution[index];

  bool get isComplete {
    for (var i = 0; i < sudokuCells; i++) {
      if (entries[i] != puzzle.solution[i]) return false;
    }
    return true;
  }

  int get remaining =>
      entries.where((e) => e == 0).length +
      List.generate(sudokuCells, (i) => i).where(isWrong).length;

  /// Writes [value] into [index]. Givens are immovable.
  SudokuGame place(int index, int value) {
    if (isGiven(index)) return this;
    final next = List<int>.of(entries)..[index] = value;
    final wrong = value != 0 && value != puzzle.solution[index];
    return SudokuGame(
      puzzle: puzzle,
      entries: List.unmodifiable(next),
      mistakes: wrong ? mistakes + 1 : mistakes,
    );
  }

  SudokuGame erase(int index) => isGiven(index) ? this : place(index, 0);
}
