import 'package:english_words/english_words.dart';

/// The pool of words used by Spelling, banded by length.
///
/// Words come from the `english_words` package's noun list, which is ordered
/// by frequency — so taking a prefix keeps the vocabulary familiar rather than
/// obscure. This replaces the previous hand-written list of 48 words, which
/// repeated within a single session.
class WordBank {
  /// How far down the frequency-ordered list to draw from. Deeper means more
  /// variety but less common words.
  static const int _commonestNouns = 2000;

  /// Words that are fine in general English but a poor fit for a family
  /// brain-training game. `english_words` does not export its own `unsafe`
  /// list, so this is a small deliberate filter of our own.
  static const Set<String> _excluded = {
    'sex',
    'death',
    'war',
    'gun',
    'drug',
    'drugs',
    'blood',
    'murder',
    'victim',
    'weapon',
    'alcohol',
    'cancer',
    'suicide',
    'tobacco',
    'crime',
    'prison',
    'enemy',
    'hell',
    'devil',
    'corpse',
    'abuse',
    'weed',
  };

  /// Length bands. Index 0 is easiest; each step up raises the memory load.
  static const List<(int, int)> _bands = [
    (3, 4),
    (5, 5),
    (6, 6),
    (7, 8),
    (9, 11),
  ];

  static List<List<String>>? _cached;

  /// Words grouped by difficulty band, computed once on first use.
  static List<List<String>> get tiers => _cached ??= _build();

  static List<List<String>> _build() {
    final pool = <String>[];
    for (final word in nouns.take(_commonestNouns)) {
      // Plain lowercase words only — the source contains entries like "CEO"
      // and multi-word or punctuated items that don't suit a spelling drill.
      if (word.length < 3 || word.length > 11) continue;
      if (!_isPlainLowercase(word)) continue;
      if (_excluded.contains(word)) continue;
      pool.add(word);
    }

    return [
      for (final (min, max) in _bands)
        pool
            .where((w) => w.length >= min && w.length <= max)
            .toList(growable: false),
    ];
  }

  static bool _isPlainLowercase(String word) {
    for (final unit in word.codeUnits) {
      if (unit < 0x61 || unit > 0x7A) return false; // a-z
    }
    return true;
  }

  /// The band index for a given difficulty level, clamped to the bands we have.
  static int tierForLevel(int level) {
    final tier = (level - 1) ~/ 2;
    return tier < 0
        ? 0
        : tier >= _bands.length
        ? _bands.length - 1
        : tier;
  }
}
