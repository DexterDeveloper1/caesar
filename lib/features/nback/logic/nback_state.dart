import 'package:flutter/foundation.dart';

import 'nback_logic.dart';

enum NBackStatus { running, finished }

/// Running tally for a single channel (position or audio).
@immutable
class ChannelStats {
  final int hits;
  final int misses;
  final int falseAlarms;
  final int correctRejections;

  const ChannelStats({
    this.hits = 0,
    this.misses = 0,
    this.falseAlarms = 0,
    this.correctRejections = 0,
  });

  int get score => channelScore(hits: hits, falseAlarms: falseAlarms);

  ChannelStats record(TrialOutcome outcome) => switch (outcome) {
    TrialOutcome.hit => _copy(hits: hits + 1),
    TrialOutcome.miss => _copy(misses: misses + 1),
    TrialOutcome.falseAlarm => _copy(falseAlarms: falseAlarms + 1),
    TrialOutcome.correctRejection => _copy(
      correctRejections: correctRejections + 1,
    ),
  };

  ChannelStats _copy({
    int? hits,
    int? misses,
    int? falseAlarms,
    int? correctRejections,
  }) {
    return ChannelStats(
      hits: hits ?? this.hits,
      misses: misses ?? this.misses,
      falseAlarms: falseAlarms ?? this.falseAlarms,
      correctRejections: correctRejections ?? this.correctRejections,
    );
  }
}

/// Immutable snapshot of a Dual N-Back session.
@immutable
class NBackState {
  final int n;
  final int totalTrials;

  /// Index of the trial currently being shown; equals [totalTrials] when done.
  final int trialIndex;

  /// The grid cell (0..8) lit right now, or null between trials.
  final int? activeCell;

  final bool positionPressed;
  final bool audioPressed;

  final ChannelStats position;
  final ChannelStats audio;

  final NBackStatus status;

  const NBackState({
    required this.n,
    required this.totalTrials,
    required this.trialIndex,
    required this.activeCell,
    required this.positionPressed,
    required this.audioPressed,
    required this.position,
    required this.audio,
    required this.status,
  });

  const NBackState.initial({required this.n, required this.totalTrials})
    : trialIndex = 0,
      activeCell = null,
      positionPressed = false,
      audioPressed = false,
      position = const ChannelStats(),
      audio = const ChannelStats(),
      status = NBackStatus.running;

  bool get isFinished => status == NBackStatus.finished;
  bool get isRunning => status == NBackStatus.running;

  /// Combined score across both channels.
  int get score => position.score + audio.score;

  /// 1-based trial number for display (clamped to [totalTrials]).
  int get trialNumber =>
      (trialIndex + 1) <= totalTrials ? trialIndex + 1 : totalTrials;

  NBackState copyWith({
    int? trialIndex,
    int? activeCell,
    bool clearActiveCell = false,
    bool? positionPressed,
    bool? audioPressed,
    ChannelStats? position,
    ChannelStats? audio,
    NBackStatus? status,
  }) {
    return NBackState(
      n: n,
      totalTrials: totalTrials,
      trialIndex: trialIndex ?? this.trialIndex,
      activeCell: clearActiveCell ? null : (activeCell ?? this.activeCell),
      positionPressed: positionPressed ?? this.positionPressed,
      audioPressed: audioPressed ?? this.audioPressed,
      position: position ?? this.position,
      audio: audio ?? this.audio,
      status: status ?? this.status,
    );
  }
}
