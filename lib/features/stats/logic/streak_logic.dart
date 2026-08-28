import 'package:flutter/foundation.dart';

/// Player progress shown on the home screen.
@immutable
class PlayerStats {
  final int currentStreak;
  final int bestStreak;
  final int gamesPlayed;

  /// Date-only string (`yyyy-mm-dd`) of the last completed session, or null.
  final String? lastPlayed;

  const PlayerStats({
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.gamesPlayed = 0,
    this.lastPlayed,
  });

  PlayerStats copyWith({
    int? currentStreak,
    int? bestStreak,
    int? gamesPlayed,
    String? lastPlayed,
  }) {
    return PlayerStats(
      currentStreak: currentStreak ?? this.currentStreak,
      bestStreak: bestStreak ?? this.bestStreak,
      gamesPlayed: gamesPlayed ?? this.gamesPlayed,
      lastPlayed: lastPlayed ?? this.lastPlayed,
    );
  }
}

/// Formats a [DateTime] as a date-only key, ignoring the time of day.
String dayKey(DateTime date) {
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '${date.year}-$m-$d';
}

/// Applies one completed session to [stats], as of [now].
///
/// Rules: playing again the same day keeps the streak; playing the next day
/// extends it; a gap of two or more days resets it to 1. Pure, so the calendar
/// behaviour is directly testable.
PlayerStats applySession(PlayerStats stats, DateTime now) {
  final today = dayKey(now);
  final yesterday = dayKey(now.subtract(const Duration(days: 1)));

  final int streak;
  if (stats.lastPlayed == today) {
    streak = stats.currentStreak == 0 ? 1 : stats.currentStreak;
  } else if (stats.lastPlayed == yesterday) {
    streak = stats.currentStreak + 1;
  } else {
    streak = 1;
  }

  return stats.copyWith(
    currentStreak: streak,
    bestStreak: streak > stats.bestStreak ? streak : stats.bestStreak,
    gamesPlayed: stats.gamesPlayed + 1,
    lastPlayed: today,
  );
}

/// True when the player has already trained today — drives the "daily goal"
/// indicator on the home screen.
bool trainedToday(PlayerStats stats, DateTime now) =>
    stats.lastPlayed == dayKey(now);
