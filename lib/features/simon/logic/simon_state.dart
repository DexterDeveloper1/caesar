import 'package:flutter/foundation.dart';

enum SimonStatus {
  /// The sequence is being played back to the player; input is disabled.
  showing,

  /// The player is repeating the sequence.
  input,

  /// The player tapped wrong; the run is over.
  gameOver,
}

/// Immutable snapshot of a Simon session.
@immutable
class SimonState {
  /// The pad indices to reproduce, in order.
  final List<int> sequence;

  /// How many pads of [sequence] the player has correctly tapped this round.
  final int inputIndex;

  /// The pad currently lit during playback, or null when nothing is lit.
  final int? activePad;

  /// Number of rounds fully completed (also the best-achievable score).
  final int level;

  final SimonStatus status;

  const SimonState({
    required this.sequence,
    required this.inputIndex,
    required this.activePad,
    required this.level,
    required this.status,
  });

  const SimonState.initial()
    : sequence = const [],
      inputIndex = 0,
      activePad = null,
      level = 0,
      status = SimonStatus.showing;

  bool get isGameOver => status == SimonStatus.gameOver;
  bool get acceptsInput => status == SimonStatus.input;

  SimonState copyWith({
    List<int>? sequence,
    int? inputIndex,
    int? level,
    SimonStatus? status,
    int? activePad,
    bool clearActivePad = false,
  }) {
    return SimonState(
      sequence: sequence ?? this.sequence,
      inputIndex: inputIndex ?? this.inputIndex,
      activePad: clearActivePad ? null : (activePad ?? this.activePad),
      level: level ?? this.level,
      status: status ?? this.status,
    );
  }
}
