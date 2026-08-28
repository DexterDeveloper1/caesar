import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Param,
  ParseIntPipe,
  Post,
  Query,
} from '@nestjs/common';

import { TrainingMode, isTrainingMode } from '../common/training-mode';
import { SubmitScoreDto } from './dto/submit-score.dto';
import { LeaderboardEntry } from './score.entity';
import { ScoresService, SubmitResult } from './scores.service';

@Controller('v1')
export class ScoresController {
  constructor(private readonly scores: ScoresService) {}

  /** Validates the `:mode` path segment against the known training modes. */
  private parseMode(mode: string): TrainingMode {
    if (!isTrainingMode(mode)) {
      throw new BadRequestException(`Unknown mode: ${mode}`);
    }
    return mode;
  }

  @Post('scores')
  submit(@Body() dto: SubmitScoreDto): Promise<SubmitResult> {
    return this.scores.submit(dto);
  }

  @Get('leaderboard/:mode')
  leaderboard(
    @Param('mode') mode: string,
    @Query('limit', new ParseIntPipe({ optional: true })) limit?: number,
    @Query('deviceId') deviceId?: string,
  ): Promise<LeaderboardEntry[]> {
    return this.scores.leaderboard(
      this.parseMode(mode),
      limit ?? ScoresService.defaultLimit,
      deviceId,
    );
  }

  @Get('leaderboard/:mode/rank')
  async rank(
    @Param('mode') mode: string,
    @Query('deviceId') deviceId?: string,
  ): Promise<{ rank: number }> {
    if (!deviceId) throw new BadRequestException('deviceId is required');
    return { rank: await this.scores.rankOf(this.parseMode(mode), deviceId) };
  }
}
