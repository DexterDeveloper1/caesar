import 'dart:convert';

import 'package:flutter/foundation.dart';

/// A word encountered during a Spelling round.
@immutable
class SeenWord {
  final String word;
  final bool wasCorrect;

  const SeenWord({required this.word, required this.wasCorrect});
}

/// Words seen in the current round.
///
/// Capture is silent and automatic — nothing is shown mid-round, because the
/// game is timed and any save control would both distract from the recall task
/// and double as a pause. Curation happens afterwards on the results screen.
@immutable
class WordSession {
  final List<SeenWord> words;

  const WordSession({this.words = const []});

  WordSession record(String word, {required bool correct}) {
    if (words.any((w) => w.word == word)) return this;
    return WordSession(
      words: [
        ...words,
        SeenWord(word: word, wasCorrect: correct),
      ],
    );
  }

  /// Words to pre-select for saving: the ones the player got wrong, which are
  /// precisely the ones worth learning.
  List<String> get suggested =>
      words.where((w) => !w.wasCorrect).map((w) => w.word).toList();

  bool get isEmpty => words.isEmpty;
}

/// A word the player chose to keep, plus its definition once looked up.
@immutable
class SavedWord {
  final String word;
  final DateTime savedAt;
  final String? definition;

  const SavedWord({required this.word, required this.savedAt, this.definition});

  SavedWord copyWith({String? definition}) => SavedWord(
    word: word,
    savedAt: savedAt,
    definition: definition ?? this.definition,
  );

  Map<String, dynamic> toJson() => {
    'word': word,
    'savedAt': savedAt.toIso8601String(),
    if (definition != null) 'definition': definition,
  };

  static SavedWord? fromJson(Object? json) {
    if (json is! Map) return null;
    final word = json['word'];
    final savedAt = DateTime.tryParse('${json['savedAt']}');
    if (word is! String || savedAt == null) return null;
    final definition = json['definition'];
    return SavedWord(
      word: word,
      savedAt: savedAt,
      definition: definition is String ? definition : null,
    );
  }
}

/// The player's short-term vocabulary list.
///
/// Deliberately temporary: entries expire after [retention] so the list stays a
/// "words to look at soon" shelf rather than an ever-growing archive.
@immutable
class SavedWords {
  final List<SavedWord> words;

  const SavedWords(this.words);

  factory SavedWords.empty() => const SavedWords([]);

  static const Duration retention = Duration(days: 7);

  SavedWords save(String word, {DateTime? at}) {
    if (words.any((w) => w.word == word)) return this;
    return SavedWords([
      ...words,
      SavedWord(word: word, savedAt: at ?? DateTime.now()),
    ]);
  }

  SavedWords remove(String word) =>
      SavedWords(words.where((w) => w.word != word).toList());

  bool contains(String word) => words.any((w) => w.word == word);

  SavedWords withDefinition(String word, String definition) => SavedWords([
    for (final w in words)
      if (w.word == word) w.copyWith(definition: definition) else w,
  ]);

  /// Drops entries past the retention window.
  SavedWords pruned({DateTime? now}) {
    final cutoff = (now ?? DateTime.now()).subtract(retention);
    return SavedWords(words.where((w) => w.savedAt.isAfter(cutoff)).toList());
  }

  String encode() => jsonEncode(words.map((w) => w.toJson()).toList());

  static SavedWords decode(String? raw) {
    if (raw == null || raw.isEmpty) return SavedWords.empty();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return SavedWords.empty();
      return SavedWords([
        for (final entry in decoded)
          if (SavedWord.fromJson(entry) case final word?) word,
      ]);
    } on FormatException {
      // Corrupt storage must never break the app.
      return SavedWords.empty();
    }
  }
}
