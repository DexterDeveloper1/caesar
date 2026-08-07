import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:caesar/features/game/logic/game_type.dart';
import 'package:caesar/services/storage_service.dart';

/// Best score per [GameType], loaded from storage and updated when a run beats
/// the existing record.
class HighscoresController extends Notifier<Map<GameType, int>> {
  StorageService get _storage => ref.read(storageServiceProvider);

  @override
  Map<GameType, int> build() => _storage.readHighscores();

  /// Records [score] for [mode] if it beats the current best. Returns true if
  /// a new record was set.
  bool submit(GameType mode, int score) {
    final best = state[mode] ?? 0;
    if (score <= best) return false;
    state = {...state, mode: score};
    _storage.writeHighscore(mode, score);
    return true;
  }
}

final highscoresControllerProvider =
    NotifierProvider<HighscoresController, Map<GameType, int>>(
      HighscoresController.new,
    );
