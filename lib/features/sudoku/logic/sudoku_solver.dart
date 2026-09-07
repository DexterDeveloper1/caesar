import 'sudoku_board.dart';

/// Backtracking solver.
///
/// [countSolutions] is the important one: a puzzle is only well-formed if it
/// has exactly one solution, so generation leans on it to decide whether a
/// clue can be removed.

/// Returns a solved copy of [cells], or null if the board cannot be solved.
List<int>? solveSudoku(List<int> cells) {
  // A board that already breaks the rules has no solution.
  for (var i = 0; i < sudokuCells; i++) {
    if (cells[i] != 0 && !isValidPlacement(cells, i, cells[i])) return null;
  }
  final work = List<int>.of(cells);
  return _search(work) ? work : null;
}

bool _search(List<int> cells) {
  final index = _mostConstrainedCell(cells);
  if (index == -1) return true; // nothing empty left

  for (var value = 1; value <= sudokuSize; value++) {
    if (!isValidPlacement(cells, index, value)) continue;
    cells[index] = value;
    if (_search(cells)) return true;
    cells[index] = 0;
  }
  return false;
}

/// Picks the empty cell with the fewest legal values, which prunes the search
/// tree dramatically compared with scanning in order.
int _mostConstrainedCell(List<int> cells) {
  var best = -1;
  var bestCount = sudokuSize + 1;
  for (var i = 0; i < sudokuCells; i++) {
    if (cells[i] != 0) continue;
    var count = 0;
    for (var value = 1; value <= sudokuSize; value++) {
      if (isValidPlacement(cells, i, value)) count++;
    }
    if (count == 0) return i; // dead end — fail fast
    if (count < bestCount) {
      bestCount = count;
      best = i;
      if (count == 1) break;
    }
  }
  return best;
}

/// Counts solutions, stopping once [cap] have been found.
///
/// Capping matters: an empty grid has ~6.7×10^21 solutions, so the answer to
/// "is this unique?" must never require enumerating them.
int countSolutions(List<int> cells, {int cap = 2}) {
  for (var i = 0; i < sudokuCells; i++) {
    if (cells[i] != 0 && !isValidPlacement(cells, i, cells[i])) return 0;
  }
  final work = List<int>.of(cells);
  var found = 0;
  _count(work, cap, () => found++, () => found);
  return found;
}

void _count(
  List<int> cells,
  int cap,
  void Function() onSolution,
  int Function() found,
) {
  if (found() >= cap) return;
  final index = _mostConstrainedCell(cells);
  if (index == -1) {
    onSolution();
    return;
  }
  for (var value = 1; value <= sudokuSize; value++) {
    if (found() >= cap) return;
    if (!isValidPlacement(cells, index, value)) continue;
    cells[index] = value;
    _count(cells, cap, onSolution, found);
    cells[index] = 0;
  }
}
