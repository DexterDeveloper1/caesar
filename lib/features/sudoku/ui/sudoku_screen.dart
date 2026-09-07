import 'package:caesar/core/design.dart';
import 'package:caesar/core/training_mode.dart';
import 'package:caesar/core/widgets/juice.dart';
import 'package:caesar/core/widgets/quit_guard.dart';
import 'package:caesar/features/game/ui/results_view.dart';
import 'package:caesar/features/sudoku/logic/sudoku_board.dart';
import 'package:caesar/features/sudoku/logic/sudoku_controller.dart';
import 'package:caesar/features/sudoku/logic/sudoku_generator.dart';
import 'package:caesar/services/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Sudoku board and number pad.
///
/// Layout follows the standard mobile pattern: cells are only big enough to
/// *select* (a 9x9 grid on a 360dp phone gives ~36dp cells, under the 48dp
/// touch minimum), while the number pad underneath gets full-size targets. All
/// actual input happens on the pad, so no control is ever too small to hit.
class SudokuScreen extends ConsumerWidget {
  const SudokuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sudokuControllerProvider);
    final controller = ref.read(sudokuControllerProvider.notifier);
    final palette = AppPalette.of(context);
    final style = styleOf(TrainingMode.sudoku);

    if (state.finished) {
      return ResultsView(
        title: 'Solved!',
        mode: TrainingMode.sudoku,
        score: state.score,
        scoreLabel:
            '${state.game.puzzle.difficulty.label}  ·  '
            '${_clock(state.elapsedSeconds)}  ·  '
            '${state.game.mistakes} mistakes',
        onRestart: controller.restart,
        restartLabel: 'New puzzle',
      );
    }

    return QuitGuard(
      message: 'This puzzle will be abandoned and will not be scored.',
      child: Scaffold(
        body: AppBackground(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(Insets.md),
              child: Column(
                children: [
                  _TopBar(difficulty: state.game.puzzle.difficulty),
                  const SizedBox(height: Insets.sm),
                  _StatusBar(
                    seconds: state.elapsedSeconds,
                    mistakes: state.game.mistakes,
                    remaining: state.game.remaining,
                  ),
                  const SizedBox(height: Insets.md),
                  // The board takes whatever square space is left.
                  Expanded(
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: _Board(
                          state: state,
                          onSelect: (index) {
                            ref.read(audioServiceProvider).tap();
                            controller.select(index);
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: Insets.md),
                  _NumberPad(
                    onNumber: (value) {
                      ref.read(audioServiceProvider).tap();
                      controller.enter(value);
                    },
                    onErase: () {
                      ref.read(audioServiceProvider).tap();
                      controller.erase();
                    },
                    accent: style.accent,
                    palette: palette,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _clock(int seconds) {
  final m = (seconds ~/ 60).toString().padLeft(2, '0');
  final s = (seconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

class _StatusBar extends StatelessWidget {
  final int seconds;
  final int mistakes;
  final int remaining;

  const _StatusBar({
    required this.seconds,
    required this.mistakes,
    required this.remaining,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    Widget item(IconData icon, String value, Color tint) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: tint),
        const SizedBox(width: Insets.xs),
        Text(
          value,
          style: TextStyle(
            color: palette.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ],
    );

    return GlassCard(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.md,
        vertical: Insets.sm,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          item(Icons.timer_outlined, _clock(seconds), palette.textMuted),
          item(
            Icons.close_rounded,
            '$mistakes',
            mistakes > 0 ? const Color(0xFFFB7185) : palette.textMuted,
          ),
          item(
            Icons.grid_goldenratio_rounded,
            '$remaining left',
            palette.textMuted,
          ),
        ],
      ),
    );
  }
}

class _Board extends StatelessWidget {
  final SudokuState state;
  final ValueChanged<int> onSelect;

  const _Board({required this.state, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final style = styleOf(TrainingMode.sudoku);

    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(Radii.sm),
        border: Border.all(color: palette.textMuted, width: 1.4),
      ),
      child: GridView.builder(
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: sudokuSize,
        ),
        itemCount: sudokuCells,
        itemBuilder: (context, index) {
          final value = state.game.valueAt(index);
          final isSelected = state.selected == index;
          final isPeer = state.highlighted.contains(index);
          // Highlighting every copy of the selected number is the single most
          // useful assist in a Sudoku UI.
          final isTwin =
              value != 0 && value == state.selectedValue && !isSelected;
          final wrong = state.game.isWrong(index);
          final given = state.game.isGiven(index);

          return _Cell(
            index: index,
            value: value,
            given: given,
            wrong: wrong,
            selected: isSelected,
            peer: isPeer,
            twin: isTwin,
            accent: style.accent,
            palette: palette,
            onTap: () => onSelect(index),
          );
        },
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  final int index;
  final int value;
  final bool given;
  final bool wrong;
  final bool selected;
  final bool peer;
  final bool twin;
  final Color accent;
  final AppPalette palette;
  final VoidCallback onTap;

  const _Cell({
    required this.index,
    required this.value,
    required this.given,
    required this.wrong,
    required this.selected,
    required this.peer,
    required this.twin,
    required this.accent,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final row = rowOf(index);
    final column = columnOf(index);

    // Heavier lines on box boundaries so the 3x3 structure is readable.
    BorderSide side(bool heavy) => BorderSide(
      color: heavy ? palette.textMuted : palette.surfaceBorder,
      width: heavy ? 1.4 : 0.6,
    );

    final background = selected
        ? accent.withValues(alpha: 0.35)
        : wrong
        ? const Color(0x33FB7185)
        : twin
        ? accent.withValues(alpha: 0.18)
        : peer
        ? palette.surfaceBorder.withValues(alpha: 0.35)
        : Colors.transparent;

    return GestureDetector(
      onTap: onTap,
      child: Semantics(
        label: 'Row ${row + 1}, column ${column + 1}',
        value: value == 0 ? 'empty' : '$value',
        selected: selected,
        child: AnimatedContainer(
          duration: Motion.instant,
          decoration: BoxDecoration(
            color: background,
            border: Border(
              top: side(row % sudokuBox == 0),
              left: side(column % sudokuBox == 0),
              right: side(column == sudokuSize - 1),
              bottom: side(row == sudokuSize - 1),
            ),
          ),
          alignment: Alignment.center,
          child: value == 0
              ? null
              : Text(
                  '$value',
                  style: TextStyle(
                    // Givens are bold and muted; your own entries use the
                    // accent so it is obvious what you put there.
                    color: wrong
                        ? const Color(0xFFFB7185)
                        : given
                        ? palette.textPrimary
                        : accent,
                    fontWeight: given ? FontWeight.w800 : FontWeight.w600,
                    fontSize: 18,
                  ),
                ),
        ),
      ),
    );
  }
}

class _NumberPad extends StatelessWidget {
  final ValueChanged<int> onNumber;
  final VoidCallback onErase;
  final Color accent;
  final AppPalette palette;

  const _NumberPad({
    required this.onNumber,
    required this.onErase,
    required this.accent,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    Widget key(Widget child, VoidCallback onTap) => Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Pressable(
          onPressed: onTap,
          child: Container(
            // Comfortably above the 48dp touch-target minimum.
            height: 52,
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(Radii.sm),
              border: Border.all(color: palette.surfaceBorder),
            ),
            alignment: Alignment.center,
            child: child,
          ),
        ),
      ),
    );

    Widget numberKey(int n) => key(
      Text(
        '$n',
        style: TextStyle(
          color: accent,
          fontSize: 22,
          fontWeight: FontWeight.w800,
        ),
      ),
      () => onNumber(n),
    );

    return Column(
      children: [
        Row(children: [for (var n = 1; n <= 5; n++) numberKey(n)]),
        const SizedBox(height: Insets.sm),
        Row(
          children: [
            for (var n = 6; n <= 9; n++) numberKey(n),
            key(
              Icon(
                Icons.backspace_outlined,
                color: palette.textMuted,
                size: 20,
              ),
              onErase,
            ),
          ],
        ),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  final SudokuDifficulty difficulty;

  const _TopBar({required this.difficulty});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final style = styleOf(TrainingMode.sudoku);
    return Row(
      children: [
        Pressable(
          onPressed: () => Navigator.of(context).maybePop(),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: palette.surface,
              shape: BoxShape.circle,
              border: Border.all(color: palette.surfaceBorder),
            ),
            child: Icon(
              Icons.arrow_back_rounded,
              color: palette.textPrimary,
              size: 20,
            ),
          ),
        ),
        const SizedBox(width: Insets.md),
        Icon(style.icon, color: style.accent, size: 20),
        const SizedBox(width: Insets.sm),
        Text(
          'Sudoku',
          style: TextStyle(
            color: palette.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Insets.sm + 2,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            gradient: style.gradient,
            borderRadius: Radii.pill,
          ),
          child: Text(
            difficulty.label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}
