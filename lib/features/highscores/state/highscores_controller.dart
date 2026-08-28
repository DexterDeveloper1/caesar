import 'package:caesar/core/training_mode.dart';
import 'package:caesar/services/storage_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Best score per [TrainingMode], loaded from storage and updated when a run
/// beats the existing record.
class HighscoresController extends Notifier<Map<TrainingMode, int>> {
  StorageService get _storage => ref.read(storageServiceProvider);

  @override
  Map<TrainingMode, int> build() => _storage.readHighscores();

  /// Records [score] for [mode] if it beats the current best. Returns true if
  /// a new record was set.
  bool submit(TrainingMode mode, int score) {
    final best = state[mode] ?? 0;
    if (score <= best) return false;
    state = {...state, mode: score};
    _storage.writeHighscore(mode, score);
    return true;
  }
}

final highscoresControllerProvider =
    NotifierProvider<HighscoresController, Map<TrainingMode, int>>(
      HighscoresController.new,
    );
