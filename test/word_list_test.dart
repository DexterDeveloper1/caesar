import 'package:caesar/features/vocabulary/logic/saved_word.dart';
import 'package:flutter_test/flutter_test.dart';

/// Written before the implementation. Describes the capture-then-curate model:
/// words are collected silently during play, and the player chooses which to
/// keep afterwards.
void main() {
  final now = DateTime(2026, 3, 10);

  group('Session capture', () {
    test('records each word with whether it was answered correctly', () {
      var session = const WordSession();
      session = session.record('mountain', correct: true);
      session = session.record('calendar', correct: false);

      expect(session.words.length, 2);
      expect(session.words.first.word, 'mountain');
      expect(session.words.first.wasCorrect, isTrue);
      expect(session.words.last.wasCorrect, isFalse);
    });

    test('does not record the same word twice in one session', () {
      var session = const WordSession();
      session = session.record('river', correct: true);
      session = session.record('river', correct: false);
      expect(session.words.length, 1);
    });

    test('words missed are suggested for saving, correct ones are not', () {
      var session = const WordSession();
      session = session.record('mountain', correct: true);
      session = session.record('calendar', correct: false);
      // The words you got wrong are exactly the ones worth learning.
      expect(session.suggested, ['calendar']);
    });
  });

  group('Saved list', () {
    test('keeps a word with the time it was saved', () {
      final list = SavedWords.empty().save('calendar', at: now);
      expect(list.words.single.word, 'calendar');
      expect(list.words.single.savedAt, now);
    });

    test('saving the same word twice does not duplicate it', () {
      final list = SavedWords.empty()
          .save('calendar', at: now)
          .save('calendar', at: now.add(const Duration(days: 1)));
      expect(list.words.length, 1);
    });

    test('a word can be removed', () {
      final list = SavedWords.empty().save('calendar', at: now);
      expect(list.remove('calendar').words, isEmpty);
    });

    test('entries older than the retention window expire', () {
      final list = SavedWords.empty()
          .save('old', at: now.subtract(const Duration(days: 30)))
          .save('fresh', at: now.subtract(const Duration(days: 2)));

      final pruned = list.pruned(now: now);
      expect(pruned.words.map((w) => w.word), ['fresh']);
    });

    test('a definition can be attached and is kept', () {
      final list = SavedWords.empty()
          .save('calendar', at: now)
          .withDefinition('calendar', 'A chart showing days and months.');

      expect(list.words.single.definition, 'A chart showing days and months.');
    });

    test('survives a round trip through storage', () {
      final list = SavedWords.empty()
          .save('calendar', at: now)
          .withDefinition('calendar', 'A chart of days.');

      final restored = SavedWords.decode(list.encode());
      expect(restored.words.single.word, 'calendar');
      expect(restored.words.single.definition, 'A chart of days.');
      expect(restored.words.single.savedAt, now);
    });

    test('decoding rubbish yields an empty list rather than throwing', () {
      expect(SavedWords.decode('not json').words, isEmpty);
      expect(SavedWords.decode(null).words, isEmpty);
    });
  });
}
