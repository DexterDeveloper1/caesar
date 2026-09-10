import 'dart:math';

import 'package:caesar/features/game/logic/game_type.dart';
import 'package:caesar/features/game/logic/progression.dart';
import 'package:caesar/features/game/logic/question_generator.dart';
import 'package:caesar/features/game/logic/word_bank.dart';
import 'package:caesar/features/nback/logic/nback_logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WordBank', () {
    test('every tier has plenty of words', () {
      for (var i = 0; i < WordBank.tiers.length; i++) {
        expect(
          WordBank.tiers[i].length,
          greaterThan(20),
          reason: 'tier $i is too small to feel varied',
        );
      }
    });

    test('words are plain lowercase and correctly banded', () {
      for (final tier in WordBank.tiers) {
        for (final word in tier) {
          expect(RegExp(r'^[a-z]{3,11}$').hasMatch(word), isTrue, reason: word);
        }
      }
      // Bands must actually get longer.
      expect(WordBank.tiers[0].first.length, lessThan(9));
      expect(WordBank.tiers[4].every((w) => w.length >= 9), isTrue);
    });
  });

  group('Spelling variety', () {
    test('a long session never repeats a word', () {
      final generator = QuestionGenerator();
      final seen = <String>{};
      for (var i = 0; i < 60; i++) {
        final q = generator.generate(GameType.spelling, 1);
        expect(seen.add(q.answer), isTrue, reason: 'repeated "${q.answer}"');
      }
    });
  });

  group('Progression', () {
    test('a level is earned by a streak, not a single answer', () {
      var p = const Progression();
      p = applyAnswer(p, correct: true);
      expect(p.level, 1, reason: 'one correct answer must not promote');
      p = applyAnswer(p, correct: true);
      expect(p.level, 1);
      p = applyAnswer(p, correct: true);
      expect(p.level, 2, reason: 'promotes after $promoteAfter in a row');
    });

    test('a wrong answer steps back down and resets the streak', () {
      var p = const Progression(level: 4, streak: 2);
      p = applyAnswer(p, correct: false);
      expect(p.level, 3);
      expect(p.streak, 0);
    });

    test('level stays within bounds', () {
      var p = const Progression();
      p = applyAnswer(p, correct: false);
      expect(p.level, 1);
      var high = const Progression(level: maxLevel, streak: 2);
      high = applyAnswer(high, correct: true);
      expect(high.level, maxLevel);
    });
  });

  group('Math difficulty curve', () {
    test('starts with small addition only', () {
      final band = mathBandForLevel(1);
      expect(band.operators, ['+']);
      expect(band.termMax, lessThanOrEqualTo(10));
    });

    test('each operation is introduced before it is mixed in', () {
      // Subtraction appears only after addition has had its own levels.
      expect(mathBandForLevel(2).operators.contains('-'), isFalse);
      expect(mathBandForLevel(3).operators.contains('-'), isTrue);
      // Multiplication debuts alone, then joins the mix.
      expect(mathBandForLevel(6).operators, ['×']);
      expect(mathBandForLevel(7).operators.contains('×'), isTrue);
      // Division debuts alone too.
      expect(mathBandForLevel(10).operators, ['÷']);
    });

    test('operand sizes never explode', () {
      // The old bug: reaching level ~10 produced things like 98 x 79.
      for (var level = 1; level <= maxLevel; level++) {
        final band = mathBandForLevel(level);
        expect(band.factorMax, lessThanOrEqualTo(12));
        expect(band.termMax, lessThanOrEqualTo(144));
      }
    });

    test('generated questions respect their band at every level', () {
      final generator = QuestionGenerator();
      for (var level = 1; level <= maxLevel; level++) {
        final band = mathBandForLevel(level);
        for (var i = 0; i < 120; i++) {
          final q = generator.generate(GameType.math, level);
          final parts = q.prompt.replaceAll(' = ?', '').split(' ');
          final a = int.parse(parts[0]);
          final op = parts[1];
          final b = int.parse(parts[2]);

          expect(
            band.operators.contains(op),
            isTrue,
            reason: 'level $level produced "$op"',
          );
          if (op == '+' || op == '-') {
            expect(a, lessThanOrEqualTo(band.termMax), reason: q.prompt);
            expect(int.parse(q.answer), greaterThanOrEqualTo(0));
          }
          if (op == '×') {
            expect(a, lessThanOrEqualTo(band.factorMax), reason: q.prompt);
            expect(b, lessThanOrEqualTo(band.factorMax), reason: q.prompt);
          }
          if (op == '÷') {
            expect(b, lessThanOrEqualTo(band.factorMax), reason: q.prompt);
            expect(a % b, 0, reason: '${q.prompt} is not exact');
          }
        }
      }
    });
  });

  group('N-Back target density', () {
    test('every session contains exactly the planned number of targets', () {
      final rng = Random(7);
      for (var n = 1; n <= 5; n++) {
        final trials = 20 + n;
        final (posTargets, audTargets) = planTargets(
          trials: trials,
          n: n,
          rng: rng,
        );
        final positions = buildSequence(
          trials: trials,
          n: n,
          alphabet: 9,
          targets: posTargets,
          rng: rng,
        );
        final letters = buildSequence(
          trials: trials,
          n: n,
          alphabet: 8,
          targets: audTargets,
          rng: rng,
        );

        var posMatches = 0, audMatches = 0;
        for (var i = 0; i < trials; i++) {
          if (isNBackMatch(positions, i, n)) posMatches++;
          if (isNBackMatch(letters, i, n)) audMatches++;
        }
        // Exact, not approximate: non-targets are forced not to match.
        expect(posMatches, targetsPerChannel, reason: 'n=$n positions');
        expect(audMatches, targetsPerChannel, reason: 'n=$n letters');
      }
    });

    test('a perfect run now scores far above the old ceiling', () {
      // Two channels x 6 targets = 12 hits available, vs ~4.7 before.
      expect(targetsPerChannel * 2, greaterThanOrEqualTo(12));
    });

    test('some targets coincide on both channels', () {
      final (pos, aud) = planTargets(trials: 22, n: 2, rng: Random(3));
      expect(pos.intersection(aud).length, dualTargets);
    });
  });

  group('N-Back has no score ceiling', () {
    test('a harder level outranks a flawless easy one', () {
      final perfectAtTwo = sessionScore(n: 2, accuracy: 1.0);
      final strongAtFour = sessionScore(n: 4, accuracy: 0.90);
      expect(strongAtFour, greaterThan(perfectAtTwo));
    });

    test('score keeps rising with N, so there is always a harder target', () {
      var previous = 0;
      for (var n = minN; n <= maxN; n++) {
        final score = sessionScore(n: n, accuracy: 1.0);
        expect(
          score,
          greaterThan(previous),
          reason: 'N=$n did not raise the ceiling',
        );
        previous = score;
      }
    });

    test('the ceiling is far above a beginner level', () {
      expect(maxN, greaterThanOrEqualTo(9));
    });

    test('accuracy still matters at a given level', () {
      expect(
        sessionScore(n: 3, accuracy: 0.95),
        greaterThan(sessionScore(n: 3, accuracy: 0.70)),
      );
    });
  });

  group('Spelling timing', () {
    // Two research anchors:
    //  * Word-recall experiments present a word for about one second.
    //  * Large-scale studies put mobile typing at ~36-38 WPM (~3 chars/sec);
    //    an unfamiliar in-app keyboard with no prediction is slower still.

    test('reveal time is near the one-second research standard', () {
      // A typical 6-letter word at the starting level.
      final ms = QuestionGenerator.revealMillis(1, 6);
      expect(ms, greaterThanOrEqualTo(800));
      expect(ms, lessThanOrEqualTo(1400));
    });

    test('a longer word is shown for longer', () {
      expect(
        QuestionGenerator.revealMillis(1, 11),
        greaterThan(QuestionGenerator.revealMillis(1, 3)),
      );
    });

    test('reveal time shrinks as the level rises', () {
      expect(
        QuestionGenerator.revealMillis(10, 6),
        lessThan(QuestionGenerator.revealMillis(1, 6)),
      );
    });

    test('reveal time never drops below a readable floor', () {
      expect(QuestionGenerator.revealMillis(99, 3), greaterThanOrEqualTo(500));
    });

    test('answer time always allows the word to be physically typed', () {
      // At a conservative 2.5 characters per second, plus a moment to recall.
      for (var length = 3; length <= 12; length++) {
        for (var level = 1; level <= maxLevel; level++) {
          final seconds = QuestionGenerator.answerSeconds(
            GameType.spelling,
            level,
            wordLength: length,
          );
          final typingTime = length / 2.5;
          expect(
            seconds,
            greaterThan(typingTime),
            reason: 'level $level, $length letters leaves no thinking time',
          );
        }
      }
    });

    test('a longer word is given more time', () {
      expect(
        QuestionGenerator.answerSeconds(GameType.spelling, 1, wordLength: 11),
        greaterThan(
          QuestionGenerator.answerSeconds(GameType.spelling, 1, wordLength: 3),
        ),
      );
    });

    test('answer time tightens with level but stays achievable', () {
      final easy = QuestionGenerator.answerSeconds(
        GameType.spelling,
        1,
        wordLength: 8,
      );
      final hard = QuestionGenerator.answerSeconds(
        GameType.spelling,
        maxLevel,
        wordLength: 8,
      );
      expect(hard, lessThan(easy));
      // Still more than the time it takes to tap eight letters.
      expect(hard, greaterThan(8 / 2.5));
    });

    test('math timing is unchanged by word length', () {
      expect(
        QuestionGenerator.answerSeconds(GameType.math, 3, wordLength: 3),
        QuestionGenerator.answerSeconds(GameType.math, 3, wordLength: 11),
      );
    });
  });
}
