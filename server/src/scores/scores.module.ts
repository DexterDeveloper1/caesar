import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

import { ScoresController } from './scores.controller';
import { FileScoresRepository, ScoresRepository } from './scores.repository';
import { ScoresService } from './scores.service';

@Module({
  controllers: [ScoresController],
  providers: [
    ScoresService,
    {
      // Bind the abstract repository to the file-backed implementation. Point
      // this at a database-backed class to scale beyond a single instance.
      provide: ScoresRepository,
      inject: [ConfigService],
      useFactory: (config: ConfigService) =>
        new FileScoresRepository(
          config.get<string>('DATA_FILE') ?? 'data/scores.json',
        ),
    },
  ],
  exports: [ScoresService],
})
export class ScoresModule {}
