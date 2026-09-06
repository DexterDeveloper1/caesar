import 'dart:math';

import 'game_type.dart';
import 'progression.dart';
import 'word_bank.dart';

/// A single generated challenge.
///
/// When [reveal] is set the word is shown briefly and then hidden, and the
/// player types it from memory ([prompt] is what stays on screen while they
/// answer). Math questions have no reveal phase — they stay visible.
class Question {
  final String prompt;
  final String answer;
  final String? reveal;

  const Question({required this.prompt, required this.answer, this.reveal});

  bool get hasRevealPhase => reveal != null;
}

/// Pure, testable question generation. No Flutter, no state beyond the
/// anti-repetition bag — inject a seeded [Random] to make output deterministic.
class QuestionGenerator {
  final Random _rng;

  QuestionGenerator([Random? rng]) : _rng = rng ?? Random();

  /// Remaining unused words per tier ("shuffle bag").
  ///
  /// Drawing without replacement means a word cannot reappear until every
  /// other word in its band has been used, which is what stops a session from
  /// feeling repetitive.
  final Map<int, List<String>> _bags = {};

  /// How long the word is shown before it is hidden, in milliseconds.
  /// Shrinks as the level climbs, with a floor so it stays readable.
  static int revealMillis(int level) => max(700, 1800 - (level - 1) * 90);

  /// Seconds allowed to answer.
  static int answerSeconds(GameType mode, int level) => switch (mode) {
    // Typing a whole word needs a little more room than a single number.
    GameType.spelling => max(6, 15 - level),
    GameType.math => max(5, 13 - level),
  };

  Question generate(GameType mode, int level) {
    return switch (mode) {
      GameType.math => _math(level),
      GameType.spelling => _spelling(level),
    };
  }

  Question _math(int level) {
    final band = mathBandForLevel(level);
    final op = band.operators[_rng.nextInt(band.operators.length)];

    switch (op) {
      case '+':
        final a = _rng.nextInt(band.termMax) + 1;
        // Keep the sum inside the band rather than letting it drift double.
        final b = _rng.nextInt(max(1, band.termMax - a)) + 1;
        return Question(prompt: '$a + $b = ?', answer: '${a + b}');
      case '-':
        var a = _rng.nextInt(band.termMax) + 1;
        var b = _rng.nextInt(band.termMax) + 1;
        // Keep results non-negative for young learners.
        if (b > a) (a, b) = (b, a);
        return Question(prompt: '$a - $b = ?', answer: '${a - b}');
      case '×':
        final a = _rng.nextInt(band.factorMax) + 1;
        final b = _rng.nextInt(band.factorMax) + 1;
        return Question(prompt: '$a × $b = ?', answer: '${a * b}');
      case '÷':
      default:
        // Built from a known product, so the division is always exact and is
        // the inverse of a times table the player has already practised.
        final answer = _rng.nextInt(band.factorMax) + 1;
        final divisor = _rng.nextInt(band.factorMax) + 1;
        return Question(
          prompt: '${answer * divisor} ÷ $divisor = ?',
          answer: '$answer',
        );
    }
  }

  /// Flash-and-recall: the word appears briefly, then the player retypes it
  /// from memory. Only the exact word is correct, so there is no ambiguity.
  Question _spelling(int level) {
    final tier = WordBank.tierForLevel(level);
    final word = _drawWord(tier);

    return Question(
      // While answering, only the shape of the word remains as a cue.
      prompt: List.filled(word.length, '•').join(' '),
      answer: word,
      reveal: word,
    );
  }

  /// Takes the next word from [tier]'s bag, refilling and reshuffling when the
  /// bag runs dry.
  String _drawWord(int tier) {
    final bag = _bags[tier] ??= _refill(tier);
    if (bag.isEmpty) {
      bag.addAll(_refill(tier));
    }
    return bag.removeLast();
  }

  List<String> _refill(int tier) {
    final words = WordBank.tiers[tier];
    if (words.isEmpty) return ['word'];
    return words.toList()..shuffle(_rng);
  }
}
