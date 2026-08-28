import 'dart:math' as math;

/// Whether the stimulus at [index] equals the one [n] steps earlier.
/// The first [n] trials can never be a match.
bool isNBackMatch(List<int> sequence, int index, int n) {
  if (index < n) return false;
  return sequence[index] == sequence[index - n];
}

/// The result of the player's response on one channel of one trial.
enum TrialOutcome { hit, miss, falseAlarm, correctRejection }

/// Classifies a response given whether the trial was actually a match and
/// whether the player claimed it was. Pure — the basis of all scoring.
TrialOutcome classifyResponse({required bool isMatch, required bool pressed}) {
  if (isMatch) return pressed ? TrialOutcome.hit : TrialOutcome.miss;
  return pressed ? TrialOutcome.falseAlarm : TrialOutcome.correctRejection;
}

/// Per-channel score: rewards hits, penalizes false alarms, never negative.
int channelScore({required int hits, required int falseAlarms}) =>
    math.max(0, hits - falseAlarms);
