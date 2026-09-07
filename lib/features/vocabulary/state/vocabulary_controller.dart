import 'package:caesar/features/vocabulary/logic/saved_word.dart';
import 'package:caesar/services/storage_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Words seen in the round that just finished.
///
/// Held in memory only: it exists so the results screen can offer them, and is
/// replaced by the next round.
class WordSessionController extends Notifier<WordSession> {
  @override
  WordSession build() => const WordSession();

  void record(String word, {required bool correct}) =>
      state = state.record(word, correct: correct);

  void clear() => state = const WordSession();
}

final wordSessionProvider =
    NotifierProvider<WordSessionController, WordSession>(
      WordSessionController.new,
    );

/// The player's saved vocabulary, persisted and pruned on load.
class SavedWordsController extends Notifier<SavedWords> {
  StorageService get _storage => ref.read(storageServiceProvider);

  @override
  SavedWords build() => _storage.readSavedWords();

  void toggle(String word) {
    state = state.contains(word) ? state.remove(word) : state.save(word);
    _storage.writeSavedWords(state);
  }

  void remove(String word) {
    state = state.remove(word);
    _storage.writeSavedWords(state);
  }

  void attachDefinition(String word, String definition) {
    state = state.withDefinition(word, definition);
    _storage.writeSavedWords(state);
  }
}

final savedWordsProvider = NotifierProvider<SavedWordsController, SavedWords>(
  SavedWordsController.new,
);
