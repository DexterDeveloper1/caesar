import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';

import { HealthController } from './health/health.controller';
import { ScoresModule } from './scores/scores.module';

@Module({
  imports: [ConfigModule.forRoot({ isGlobal: true }), ScoresModule],
  controllers: [HealthController],
})
export class AppModule {}
