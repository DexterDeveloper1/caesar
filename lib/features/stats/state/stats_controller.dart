import 'package:caesar/features/stats/logic/streak_logic.dart';
import 'package:caesar/services/storage_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Persists the player's streak and lifetime game count.
class StatsController extends Notifier<PlayerStats> {
  StorageService get _storage => ref.read(storageServiceProvider);

  @override
  PlayerStats build() => _storage.readStats();

  /// Records that a session was completed. Call once per finished run.
  void recordSession({DateTime? now}) {
    state = applySession(state, now ?? DateTime.now());
    _storage.writeStats(state);
  }
}

final statsControllerProvider = NotifierProvider<StatsController, PlayerStats>(
  StatsController.new,
);
