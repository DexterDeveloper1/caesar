import {
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  Length,
  Matches,
  Max,
  Min,
} from 'class-validator';

import { TRAINING_MODES, TrainingMode } from '../../common/training-mode';

/** Upper bound on any submitted score — a cheap sanity check on the input. */
export const MAX_SCORE = 100_000;

export class SubmitScoreDto {
  /**
   * Anonymous, client-generated identifier. No account or personal data is
   * involved, so the leaderboard needs no sign-in.
   */
  @IsString()
  @Length(8, 64)
  @Matches(/^[A-Za-z0-9_-]+$/, {
    message: 'deviceId must be url-safe (A-Z, a-z, 0-9, _ or -)',
  })
  deviceId!: string;

  @IsOptional()
  @IsString()
  @Length(1, 24)
  displayName?: string;

  @IsIn(TRAINING_MODES as unknown as string[])
  mode!: TrainingMode;

  @IsInt()
  @Min(0)
  @Max(MAX_SCORE)
  score!: number;
}
