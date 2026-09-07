/// Board geometry and the placement rule.
///
/// A board is a flat `List<int>` of 81 cells in row-major order, where 0 means
/// empty. Keeping it flat (rather than nested lists) makes copying cheap, which
/// matters because the solver copies boards constantly.
const int sudokuSize = 9;
const int sudokuCells = sudokuSize * sudokuSize;
const int sudokuBox = 3;

int rowOf(int index) => index ~/ sudokuSize;
int columnOf(int index) => index % sudokuSize;

/// 0-8, reading boxes left-to-right then top-to-bottom.
int boxOf(int index) =>
    (rowOf(index) ~/ sudokuBox) * sudokuBox + columnOf(index) ~/ sudokuBox;

/// Whether [value] may be written at [index] without breaking Sudoku's rules.
///
/// The cell's own current value is ignored, so re-placing the value already
/// there is always legal.
bool isValidPlacement(List<int> cells, int index, int value) {
  if (value == 0) return true;
  final row = rowOf(index);
  final column = columnOf(index);
  final box = boxOf(index);

  for (var i = 0; i < sudokuCells; i++) {
    if (i == index || cells[i] != value) continue;
    if (rowOf(i) == row || columnOf(i) == column || boxOf(i) == box) {
      return false;
    }
  }
  return true;
}

/// True when every cell is filled and no rule is broken.
bool isSolved(List<int> cells) {
  for (var i = 0; i < sudokuCells; i++) {
    if (cells[i] == 0) return false;
    if (!isValidPlacement(cells, i, cells[i])) return false;
  }
  return true;
}

/// Indices sharing a row, column or box with [index] — used by the UI to
/// highlight the cells a selection affects.
Set<int> peersOf(int index) {
  final row = rowOf(index);
  final column = columnOf(index);
  final box = boxOf(index);
  return {
    for (var i = 0; i < sudokuCells; i++)
      if (i != index &&
          (rowOf(i) == row || columnOf(i) == column || boxOf(i) == box))
        i,
  };
}
