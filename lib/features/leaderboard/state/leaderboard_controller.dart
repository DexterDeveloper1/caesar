import 'dart:math';

import 'package:caesar/core/training_mode.dart';
import 'package:caesar/features/leaderboard/data/leaderboard_api.dart';
import 'package:caesar/services/storage_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The API base URL. Empty means "offline only" — the app then never makes a
/// network call and the global leaderboard UI stays hidden.
///
/// Override at build time:
/// `flutter run --dart-define=CAESAR_API_URL=http://10.0.2.2:3000`
const String kApiBaseUrl = String.fromEnvironment('CAESAR_API_URL');

/// True when the app was built with a server to talk to.
final onlineEnabledProvider = Provider<bool>((ref) => kApiBaseUrl.isNotEmpty);

/// Stable anonymous identifier for this install, generated once and persisted.
final deviceIdProvider = Provider<String>((ref) {
  final storage = ref.watch(storageServiceProvider);
  final existing = storage.readDeviceId();
  if (existing != null && existing.isNotEmpty) return existing;

  final random = Random.secure();
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  final id = List.generate(
    20,
    (_) => chars[random.nextInt(chars.length)],
  ).join();
  storage.writeDeviceId(id);
  return id;
});

final leaderboardApiProvider = Provider<LeaderboardApi?>((ref) {
  if (!ref.watch(onlineEnabledProvider)) return null;
  final api = LeaderboardApi(baseUrl: kApiBaseUrl);
  ref.onDispose(api.dispose);
  return api;
});

/// Submits a score to the global leaderboard, ignoring failures so a missing
/// or unreachable server never interrupts play.
final submitScoreProvider = Provider<Future<void> Function(TrainingMode, int)>((
  ref,
) {
  return (mode, score) async {
    final api = ref.read(leaderboardApiProvider);
    if (api == null) return;
    try {
      await api.submitScore(
        deviceId: ref.read(deviceIdProvider),
        mode: mode,
        score: score,
        displayName: ref.read(storageServiceProvider).readDisplayName(),
      );
    } on LeaderboardException {
      // Offline-first: a failed sync is not an error the player must see.
    }
  };
});

/// Fetches the global top scores for a mode.
final leaderboardProvider =
    FutureProvider.family<List<LeaderboardEntry>, TrainingMode>((
      ref,
      mode,
    ) async {
      final api = ref.watch(leaderboardApiProvider);
      if (api == null) return const [];
      return api.leaderboard(mode: mode, deviceId: ref.read(deviceIdProvider));
    });
