import 'dart:math';

import 'package:caesar/features/sudoku/logic/sudoku_board.dart';
import 'package:caesar/features/sudoku/logic/sudoku_generator.dart';
import 'package:caesar/features/sudoku/logic/sudoku_scoring.dart';
import 'package:caesar/features/sudoku/logic/sudoku_solver.dart';
import 'package:flutter_test/flutter_test.dart';

/// Written before the implementation: these describe what a correct Sudoku
/// engine must do, and the code exists to satisfy them.
void main() {
  group('Board rules', () {
    test('an empty board accepts any value anywhere', () {
      final cells = List.filled(81, 0);
      expect(isValidPlacement(cells, 0, 5), isTrue);
    });

    test('rejects a duplicate in the same row', () {
      final cells = List.filled(81, 0);
      cells[0] = 5;
      expect(isValidPlacement(cells, 8, 5), isFalse);
      expect(isValidPlacement(cells, 8, 6), isTrue);
    });

    test('rejects a duplicate in the same column', () {
      final cells = List.filled(81, 0);
      cells[0] = 7;
      expect(isValidPlacement(cells, 72, 7), isFalse); // same column, last row
    });

    test('rejects a duplicate in the same 3x3 box', () {
      final cells = List.filled(81, 0);
      cells[0] = 3;
      expect(isValidPlacement(cells, 20, 3), isFalse); // row 2, col 2
      expect(isValidPlacement(cells, 20, 4), isTrue);
    });

    test('a cell never conflicts with itself', () {
      final cells = List.filled(81, 0);
      cells[40] = 9;
      expect(isValidPlacement(cells, 40, 9), isTrue);
    });
  });

  group('Solver', () {
    test('solves a board and the result is complete and legal', () {
      final puzzle = generateSudoku(SudokuDifficulty.easy, rng: Random(1));
      final solved = solveSudoku(puzzle.givens);
      expect(solved, isNotNull);
      expect(isSolved(solved!), isTrue);
    });

    test('reports no solution for a contradictory board', () {
      final cells = List.filled(81, 0);
      cells[0] = 1;
      cells[1] = 1; // duplicate in row 0 — unsolvable
      expect(solveSudoku(cells), isNull);
    });

    test('counts multiple solutions when a puzzle is under-constrained', () {
      // A nearly empty grid has an enormous number of solutions; the counter
      // must stop early rather than enumerate them.
      final cells = List.filled(81, 0);
      expect(countSolutions(cells), 2);
    });
  });

  group('Generator', () {
    test('every generated puzzle has exactly one solution', () {
      for (final difficulty in SudokuDifficulty.values) {
        final puzzle = generateSudoku(difficulty, rng: Random(42));
        expect(
          countSolutions(puzzle.givens),
          1,
          reason: '${difficulty.name} puzzle is ambiguous',
        );
      }
    });

    test('the stored solution actually solves the givens', () {
      final puzzle = generateSudoku(SudokuDifficulty.medium, rng: Random(7));
      expect(isSolved(puzzle.solution), isTrue);
      for (var i = 0; i < 81; i++) {
        if (puzzle.givens[i] != 0) {
          expect(puzzle.givens[i], puzzle.solution[i]);
        }
      }
    });

    test('harder difficulties reveal fewer clues', () {
      int clues(SudokuDifficulty d) =>
          generateSudoku(d, rng: Random(3)).givens.where((c) => c != 0).length;

      expect(
        clues(SudokuDifficulty.easy),
        greaterThan(clues(SudokuDifficulty.hard)),
      );
    });

    test('never produces fewer than the 17-clue minimum', () {
      // 17 is the proven minimum number of clues for a unique solution.
      for (final difficulty in SudokuDifficulty.values) {
        final puzzle = generateSudoku(difficulty, rng: Random(11));
        expect(
          puzzle.givens.where((c) => c != 0).length,
          greaterThanOrEqualTo(17),
        );
      }
    });

    test('different seeds produce different puzzles', () {
      final a = generateSudoku(SudokuDifficulty.easy, rng: Random(1));
      final b = generateSudoku(SudokuDifficulty.easy, rng: Random(2));
      expect(a.givens, isNot(equals(b.givens)));
    });
  });

  group('Playing a puzzle', () {
    test('a fresh game exposes the givens as locked', () {
      final puzzle = generateSudoku(SudokuDifficulty.easy, rng: Random(5));
      final game = SudokuGame.from(puzzle);
      for (var i = 0; i < 81; i++) {
        expect(game.isGiven(i), puzzle.givens[i] != 0);
      }
      expect(game.isComplete, isFalse);
    });

    test('a given cannot be overwritten', () {
      final puzzle = generateSudoku(SudokuDifficulty.easy, rng: Random(5));
      final game = SudokuGame.from(puzzle);
      final givenIndex = List.generate(
        81,
        (i) => i,
      ).firstWhere((i) => puzzle.givens[i] != 0);
      final before = game.valueAt(givenIndex);
      final after = game.place(givenIndex, 5);
      expect(after.valueAt(givenIndex), before);
    });

    test('filling every cell correctly completes the puzzle', () {
      final puzzle = generateSudoku(SudokuDifficulty.easy, rng: Random(5));
      var game = SudokuGame.from(puzzle);
      for (var i = 0; i < 81; i++) {
        if (!game.isGiven(i)) game = game.place(i, puzzle.solution[i]);
      }
      expect(game.isComplete, isTrue);
      expect(game.mistakes, 0);
    });

    test('a wrong entry is recorded as a mistake but still shown', () {
      final puzzle = generateSudoku(SudokuDifficulty.easy, rng: Random(5));
      var game = SudokuGame.from(puzzle);
      final blank = List.generate(
        81,
        (i) => i,
      ).firstWhere((i) => puzzle.givens[i] == 0);
      final wrong = puzzle.solution[blank] == 9 ? 1 : 9;
      game = game.place(blank, wrong);
      expect(game.valueAt(blank), wrong);
      expect(game.mistakes, 1);
      expect(game.isWrong(blank), isTrue);
    });

    test('erasing clears a filled cell', () {
      final puzzle = generateSudoku(SudokuDifficulty.easy, rng: Random(5));
      var game = SudokuGame.from(puzzle);
      final blank = List.generate(
        81,
        (i) => i,
      ).firstWhere((i) => puzzle.givens[i] == 0);
      game = game.place(blank, 4).erase(blank);
      expect(game.valueAt(blank), 0);
    });
  });

  group('Scoring', () {
    test('finishing faster scores higher', () {
      final quick = sudokuScore(
        difficulty: SudokuDifficulty.medium,
        seconds: 120,
        mistakes: 0,
      );
      final slow = sudokuScore(
        difficulty: SudokuDifficulty.medium,
        seconds: 600,
        mistakes: 0,
      );
      expect(quick, greaterThan(slow));
    });

    test('mistakes cost points', () {
      final clean = sudokuScore(
        difficulty: SudokuDifficulty.medium,
        seconds: 300,
        mistakes: 0,
      );
      final messy = sudokuScore(
        difficulty: SudokuDifficulty.medium,
        seconds: 300,
        mistakes: 4,
      );
      expect(messy, lessThan(clean));
    });

    test('a harder puzzle is worth more for the same run', () {
      final easy = sudokuScore(
        difficulty: SudokuDifficulty.easy,
        seconds: 300,
        mistakes: 0,
      );
      final expert = sudokuScore(
        difficulty: SudokuDifficulty.expert,
        seconds: 300,
        mistakes: 0,
      );
      expect(expert, greaterThan(easy));
    });

    test('score never goes negative, however bad the run', () {
      expect(
        sudokuScore(
          difficulty: SudokuDifficulty.easy,
          seconds: 99999,
          mistakes: 999,
        ),
        0,
      );
    });
  });
}
