import { TrainingMode } from '../common/training-mode';

/** One recorded personal best for a device in a single mode. */
export interface ScoreRecord {
  deviceId: string;
  displayName: string;
  mode: TrainingMode;
  score: number;
  /** ISO-8601 timestamp of when this best was set. */
  updatedAt: string;
}

/** A leaderboard row, as returned to clients. */
export interface LeaderboardEntry {
  rank: number;
  displayName: string;
  score: number;
  updatedAt: string;
  /** True when this row belongs to the requesting device. */
  isYou?: boolean;
}
