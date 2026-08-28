import { Controller, Get } from '@nestjs/common';

@Controller()
export class HealthController {
  /** Liveness probe for deployments and for the app's connectivity check. */
  @Get('health')
  health(): { status: string; uptime: number } {
    return { status: 'ok', uptime: Math.round(process.uptime()) };
  }
}
