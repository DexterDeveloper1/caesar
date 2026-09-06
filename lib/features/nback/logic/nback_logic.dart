import 'dart:math' as math;
import 'dart:math' show Random;

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

/// Bounds on the working-memory load.
const int minN = 1;
const int maxN = 5;

/// Targets planted per channel in a session, and how many coincide on the same
/// trial.
///
/// Purely random stimuli only produce a match ~1/9 of the time, which meant a
/// session contained barely two targets per channel and a perfect run scored
/// about 4. The established task (Brain Workshop's Jaeggi mode) instead plants
/// a fixed number of targets — roughly 30% of trials — so the task is dense
/// enough to actually train, and to score.
const int targetsPerChannel = 6;
const int dualTargets = 2;

/// Chooses which trial indices are targets.
///
/// Only indices at or after [n] can be matches. Returns (position, audio) index
/// sets sharing [dualTargets] entries.
(Set<int>, Set<int>) planTargets({
  required int trials,
  required int n,
  required Random rng,
  int perChannel = targetsPerChannel,
  int dual = dualTargets,
}) {
  final candidates = [for (var i = n; i < trials; i++) i]..shuffle(rng);
  final capped = math.min(perChannel, candidates.length);
  final shared = math.min(dual, capped);

  final position = <int>{};
  final audio = <int>{};

  // Shared targets first, then top each channel up from what remains.
  var cursor = 0;
  for (var i = 0; i < shared && cursor < candidates.length; i++, cursor++) {
    position.add(candidates[cursor]);
    audio.add(candidates[cursor]);
  }
  while (position.length < capped && cursor < candidates.length) {
    position.add(candidates[cursor++]);
  }
  while (audio.length < capped && cursor < candidates.length) {
    audio.add(candidates[cursor++]);
  }
  return (position, audio);
}

/// Builds a stimulus stream where exactly [targets] are n-back matches.
///
/// Non-target trials are actively forced *not* to match, so the target count is
/// exact rather than approximate.
List<int> buildSequence({
  required int trials,
  required int n,
  required int alphabet,
  required Set<int> targets,
  required Random rng,
}) {
  final seq = List<int>.filled(trials, 0);
  for (var i = 0; i < trials; i++) {
    if (i >= n && targets.contains(i)) {
      seq[i] = seq[i - n];
    } else if (i >= n && alphabet > 1) {
      // Draw anything except the value that would create an accidental match.
      var value = rng.nextInt(alphabet - 1);
      if (value >= seq[i - n]) value++;
      seq[i] = value;
    } else {
      seq[i] = rng.nextInt(alphabet);
    }
  }
  return seq;
}

/// Accuracy over a session: correct decisions ÷ total decisions.
double sessionAccuracy({
  required int hits,
  required int misses,
  required int falseAlarms,
  required int correctRejections,
}) {
  final total = hits + misses + falseAlarms + correctRejections;
  if (total == 0) return 0;
  return (hits + correctRejections) / total;
}

/// Chooses the next session's N from how the last one went.
///
/// This follows the standard adaptive n-back protocol: move up when accuracy
/// is high, drop back when it collapses, and otherwise hold. Keeping the task
/// near the edge of ability is what makes the training progressive rather than
/// a fixed drill.
int nextN(int currentN, double accuracy) {
  // Brain Workshop's thresholds: 80%+ moves up, below 50% moves down.
  if (accuracy >= 0.80) return math.min(maxN, currentN + 1);
  if (accuracy < 0.50) return math.max(minN, currentN - 1);
  return currentN;
}
