import { Injectable } from '@nestjs/common';

import { TrainingMode } from '../common/training-mode';
import { SubmitScoreDto } from './dto/submit-score.dto';
import { LeaderboardEntry, ScoreRecord } from './score.entity';
import { ScoresRepository } from './scores.repository';

/** Result of a submission, so the client can celebrate a genuine improvement. */
export interface SubmitResult {
  best: number;
  improved: boolean;
  rank: number;
}

@Injectable()
export class ScoresService {
  static readonly defaultLimit = 50;
  static readonly maxLimit = 200;

  constructor(private readonly repository: ScoresRepository) {}

  /** Highest first; earlier achievers win ties. */
  private static compare(a: ScoreRecord, b: ScoreRecord): number {
    if (b.score !== a.score) return b.score - a.score;
    return a.updatedAt.localeCompare(b.updatedAt);
  }

  private sanitizeName(name: string | undefined): string {
    const trimmed = (name ?? '').trim();
    return trimmed.length > 0 ? trimmed : 'Anonymous';
  }

  async submit(dto: SubmitScoreDto): Promise<SubmitResult> {
    const previous = await this.repository.findOne(dto.mode, dto.deviceId);
    const stored = await this.repository.upsertBest({
      deviceId: dto.deviceId,
      displayName: this.sanitizeName(dto.displayName),
      mode: dto.mode,
      score: dto.score,
      updatedAt: new Date().toISOString(),
    });

    const rank = await this.rankOf(dto.mode, dto.deviceId);
    return {
      best: stored.score,
      improved: !previous || dto.score > previous.score,
      rank,
    };
  }

  async leaderboard(
    mode: TrainingMode,
    limit = ScoresService.defaultLimit,
    deviceId?: string,
  ): Promise<LeaderboardEntry[]> {
    const capped = Math.min(Math.max(limit, 1), ScoresService.maxLimit);
    const sorted = (await this.repository.findByMode(mode)).sort(
      ScoresService.compare,
    );

    return sorted.slice(0, capped).map((record, index) => ({
      rank: index + 1,
      displayName: record.displayName,
      score: record.score,
      updatedAt: record.updatedAt,
      ...(deviceId && record.deviceId === deviceId ? { isYou: true } : {}),
    }));
  }

  /** 1-based rank for a device, or 0 when it has no score in that mode. */
  async rankOf(mode: TrainingMode, deviceId: string): Promise<number> {
    const sorted = (await this.repository.findByMode(mode)).sort(
      ScoresService.compare,
    );
    const index = sorted.findIndex((r) => r.deviceId === deviceId);
    return index === -1 ? 0 : index + 1;
  }
}
