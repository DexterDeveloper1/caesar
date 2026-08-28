/**
 * The training modes the app can submit scores for.
 *
 * Kept in sync with `lib/core/training_mode.dart` in the Flutter client — the
 * wire format is the enum's lowercase name.
 */
export const TRAINING_MODES = ['spelling', 'math', 'simon', 'nback'] as const;

export type TrainingMode = (typeof TRAINING_MODES)[number];

export function isTrainingMode(value: string): value is TrainingMode {
  return (TRAINING_MODES as readonly string[]).includes(value);
}
