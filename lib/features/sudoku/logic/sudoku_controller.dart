import 'dart:async';

import 'package:caesar/core/training_mode.dart';
import 'package:caesar/features/highscores/state/highscores_controller.dart';
import 'package:caesar/features/stats/state/stats_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'sudoku_board.dart';
import 'sudoku_generator.dart';
import 'sudoku_scoring.dart';

/// The chosen difficulty for the next puzzle, so the picker and the board agree.
class SudokuDifficultyController extends Notifier<SudokuDifficulty> {
  @override
  SudokuDifficulty build() => SudokuDifficulty.easy;

  void set(SudokuDifficulty difficulty) => state = difficulty;
}

final sudokuDifficultyProvider =
    NotifierProvider<SudokuDifficultyController, SudokuDifficulty>(
      SudokuDifficultyController.new,
    );

@immutable
class SudokuState {
  final SudokuGame game;

  /// Currently selected cell, or null.
  final int? selected;

  final int elapsedSeconds;
  final bool finished;

  /// True while the first puzzle is being generated.
  final bool loading;

  const SudokuState({
    required this.game,
    required this.selected,
    required this.elapsedSeconds,
    required this.finished,
    this.loading = false,
  });

  int get score => sudokuScore(
    difficulty: game.puzzle.difficulty,
    seconds: elapsedSeconds,
    mistakes: game.mistakes,
  );

  /// Cells sharing a row, column or box with the selection.
  Set<int> get highlighted => selected == null ? const {} : peersOf(selected!);

  /// The value in the selected cell, used to highlight all its twins.
  int get selectedValue => selected == null ? 0 : game.valueAt(selected!);

  SudokuState copyWith({
    SudokuGame? game,
    int? selected,
    bool clearSelection = false,
    int? elapsedSeconds,
    bool? finished,
    bool? loading,
  }) {
    return SudokuState(
      game: game ?? this.game,
      selected: clearSelection ? null : (selected ?? this.selected),
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      finished: finished ?? this.finished,
      loading: loading ?? this.loading,
    );
  }
}

class SudokuController extends Notifier<SudokuState> {
  Timer? _timer;

  @override
  SudokuState build() {
    ref.onDispose(() => _timer?.cancel());
    final difficulty = ref.read(sudokuDifficultyProvider);
    // Generation is fast (well under a frame budget in practice), so it runs
    // inline rather than through an isolate.
    final puzzle = generateSudoku(difficulty);
    _startClock();
    return SudokuState(
      game: SudokuGame.from(puzzle),
      selected: null,
      elapsedSeconds: 0,
      finished: false,
    );
  }

  void _startClock() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.finished) return;
      state = state.copyWith(elapsedSeconds: state.elapsedSeconds + 1);
    });
  }

  void select(int index) {
    if (state.finished) return;
    state = state.copyWith(selected: index);
  }

  void enter(int value) {
    final index = state.selected;
    if (index == null || state.finished) return;
    if (state.game.isGiven(index)) return;

    final game = state.game.place(index, value);
    state = state.copyWith(game: game);
    if (game.isComplete) _finish();
  }

  void erase() {
    final index = state.selected;
    if (index == null || state.finished) return;
    state = state.copyWith(game: state.game.erase(index));
  }

  void _finish() {
    _timer?.cancel();
    state = state.copyWith(finished: true, clearSelection: true);
    ref
        .read(highscoresControllerProvider.notifier)
        .submit(TrainingMode.sudoku, state.score);
    ref.read(statsControllerProvider.notifier).recordSession();
  }

  /// Starts a fresh puzzle at the currently selected difficulty.
  void restart() {
    _timer?.cancel();
    final puzzle = generateSudoku(ref.read(sudokuDifficultyProvider));
    state = SudokuState(
      game: SudokuGame.from(puzzle),
      selected: null,
      elapsedSeconds: 0,
      finished: false,
    );
    _startClock();
  }
}

final sudokuControllerProvider =
    NotifierProvider.autoDispose<SudokuController, SudokuState>(
      SudokuController.new,
    );
