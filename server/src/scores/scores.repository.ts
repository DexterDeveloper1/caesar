import { Injectable } from '@nestjs/common';
import { mkdirSync, readFileSync, renameSync, writeFileSync } from 'node:fs';
import { dirname } from 'node:path';

import { TrainingMode } from '../common/training-mode';
import { ScoreRecord } from './score.entity';

/**
 * Storage contract for scores.
 *
 * The service depends only on this, so swapping the JSON file store below for
 * Postgres/Prisma is a one-class change with no impact on the HTTP layer.
 */
export abstract class ScoresRepository {
  /** Stores the record if it beats the device's existing best. */
  abstract upsertBest(record: ScoreRecord): Promise<ScoreRecord>;

  /** All recorded bests for a mode, unsorted. */
  abstract findByMode(mode: TrainingMode): Promise<ScoreRecord[]>;

  /** A single device's best for a mode, if any. */
  abstract findOne(
    mode: TrainingMode,
    deviceId: string,
  ): Promise<ScoreRecord | undefined>;
}

/**
 * Zero-dependency persistence: the whole table is held in memory and mirrored
 * to a JSON file after each write.
 *
 * Good enough for a single-instance leaderboard and it runs anywhere with no
 * native modules or database server. For multi-instance deployments, replace
 * this with a real database implementation of [ScoresRepository].
 */
@Injectable()
export class FileScoresRepository extends ScoresRepository {
  private readonly records = new Map<string, ScoreRecord>();

  constructor(private readonly filePath: string) {
    super();
    this.load();
  }

  private key(mode: TrainingMode, deviceId: string): string {
    return `${mode}:${deviceId}`;
  }

  private load(): void {
    try {
      const raw = readFileSync(this.filePath, 'utf8');
      const parsed = JSON.parse(raw) as ScoreRecord[];
      for (const record of parsed) {
        this.records.set(this.key(record.mode, record.deviceId), record);
      }
    } catch {
      // A missing or unreadable file simply means "no scores yet".
    }
  }

  private persist(): void {
    const payload = JSON.stringify([...this.records.values()], null, 2);
    mkdirSync(dirname(this.filePath), { recursive: true });
    // Write to a temp file first so a crash mid-write cannot corrupt the data.
    const tmp = `${this.filePath}.tmp`;
    writeFileSync(tmp, payload, 'utf8');
    renameSync(tmp, this.filePath);
  }

  async upsertBest(record: ScoreRecord): Promise<ScoreRecord> {
    const key = this.key(record.mode, record.deviceId);
    const existing = this.records.get(key);

    // Only overwrite when the new score is strictly better, so replaying an
    // old submission cannot lower someone's best.
    if (existing && existing.score >= record.score) {
      return existing;
    }

    this.records.set(key, record);
    this.persist();
    return record;
  }

  async findByMode(mode: TrainingMode): Promise<ScoreRecord[]> {
    return [...this.records.values()].filter((r) => r.mode === mode);
  }

  async findOne(
    mode: TrainingMode,
    deviceId: string,
  ): Promise<ScoreRecord | undefined> {
    return this.records.get(this.key(mode, deviceId));
  }
}
