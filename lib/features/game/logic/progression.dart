import 'package:flutter/foundation.dart';

/// How the games get harder.
///
/// Two ideas from difficulty-curve design drive this:
///
/// * **Flow channel** — challenge must track the player's actual skill. So a
///   level is earned by [promoteAfter] answers in a row, not by a single lucky
///   one, and a wrong answer steps back down. Previously every correct answer
///   bumped difficulty, which is why a run could sprint from `1 + 1` to
///   `98 × 79`.
/// * **Sawtooth, not a ramp** — a new operation is introduced on its own at a
///   small size, then mixed with what came before, then its size grows. Each
///   new mechanic arrives in a low-stakes context rather than on top of a peak.
@immutable
class Progression {
  /// 1-based skill level.
  final int level;

  /// Correct answers in a row at the current level.
  final int streak;

  const Progression({this.level = 1, this.streak = 0});

  @override
  bool operator ==(Object other) =>
      other is Progression && other.level == level && other.streak == streak;

  @override
  int get hashCode => Object.hash(level, streak);

  @override
  String toString() => 'Progression(level: $level, streak: $streak)';
}

/// Consecutive correct answers needed to move up a level.
const int promoteAfter = 3;

/// Upper bound on skill level.
const int maxLevel = 12;

/// Applies one answer, returning the new progression.
Progression applyAnswer(Progression current, {required bool correct}) {
  if (!correct) {
    // Drop back to a level the player has already handled.
    return Progression(level: current.level > 1 ? current.level - 1 : 1);
  }
  final streak = current.streak + 1;
  if (streak >= promoteAfter && current.level < maxLevel) {
    return Progression(level: current.level + 1);
  }
  return Progression(level: current.level, streak: streak);
}

/// The arithmetic allowed at a given level.
@immutable
class MathBand {
  /// Operators in play, e.g. `['+', '-']`.
  final List<String> operators;

  /// Largest operand for `+` and `-`.
  final int termMax;

  /// Largest factor for `×`, and largest quotient/divisor for `÷`.
  final int factorMax;

  const MathBand({
    required this.operators,
    required this.termMax,
    required this.factorMax,
  });
}

/// Level → arithmetic band.
///
/// Addition is mastered before subtraction joins it; the range grows before
/// multiplication appears; multiplication starts at the 2–5 times tables and is
/// mixed in before it grows; division arrives last, as the inverse of tables
/// the player has already practised.
const List<MathBand> _mathBands = [
  MathBand(operators: ['+'], termMax: 10, factorMax: 5), // 1
  MathBand(operators: ['+'], termMax: 20, factorMax: 5), // 2
  MathBand(operators: ['+', '-'], termMax: 20, factorMax: 5), // 3
  MathBand(operators: ['+', '-'], termMax: 50, factorMax: 5), // 4
  MathBand(operators: ['+', '-'], termMax: 100, factorMax: 5), // 5
  MathBand(operators: ['×'], termMax: 100, factorMax: 5), // 6
  MathBand(operators: ['+', '-', '×'], termMax: 100, factorMax: 5), // 7
  MathBand(operators: ['×'], termMax: 100, factorMax: 10), // 8
  MathBand(operators: ['+', '-', '×'], termMax: 100, factorMax: 10), // 9
  MathBand(operators: ['÷'], termMax: 100, factorMax: 10), // 10
  MathBand(operators: ['+', '-', '×', '÷'], termMax: 100, factorMax: 10), // 11
  MathBand(operators: ['+', '-', '×', '÷'], termMax: 144, factorMax: 12), // 12
];

MathBand mathBandForLevel(int level) {
  final index = level - 1;
  if (index < 0) return _mathBands.first;
  if (index >= _mathBands.length) return _mathBands.last;
  return _mathBands[index];
}
