import 'dart:math';
import 'game_type.dart';

/// A single generated challenge: what the player sees ([prompt]) and the
/// value that counts as correct ([answer], compared case-insensitively).
class Question {
  final String prompt;
  final String answer;

  const Question({required this.prompt, required this.answer});
}

/// Pure, testable question generation. No Flutter, no state — inject a seeded
/// [Random] to make output deterministic in tests.
class QuestionGenerator {
  final Random _rng;

  QuestionGenerator([Random? rng]) : _rng = rng ?? Random();

  static const List<String> _words = [
    'cat',
    'train',
    'school',
    'banana',
    'keyboard',
    'flutter',
    'electric',
  ];

  Question generate(GameType mode, int difficulty) {
    return switch (mode) {
      GameType.math => _math(difficulty),
      GameType.spelling => _spelling(),
    };
  }

  Question _math(int difficulty) {
    // Only expose ×/÷ as difficulty climbs.
    final ops = ['+', '-', '×', '÷'];
    final op = ops[_rng.nextInt(min(ops.length, 2 + difficulty ~/ 2))];
    int a = _rng.nextInt(10 * difficulty) + 1;
    int b = _rng.nextInt(10 * difficulty) + 1;

    switch (op) {
      case '+':
        return Question(prompt: '$a + $b = ?', answer: '${a + b}');
      case '-':
        // Keep results non-negative for young learners.
        if (b > a) (a, b) = (b, a);
        return Question(prompt: '$a - $b = ?', answer: '${a - b}');
      case '×':
        return Question(prompt: '$a × $b = ?', answer: '${a * b}');
      case '÷':
      default:
        // Build a division that divides evenly, so the answer is exact.
        b = _rng.nextInt(9) + 1;
        final product = a * b;
        return Question(prompt: '$product ÷ $b = ?', answer: '$a');
    }
  }

  Question _spelling() {
    final word = _words[_rng.nextInt(_words.length)];
    final missingIndex = _rng.nextInt(word.length);
    return Question(
      prompt: word.replaceRange(missingIndex, missingIndex + 1, '_'),
      answer: word[missingIndex],
    );
  }
}
