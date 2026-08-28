import { ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import 'reflect-metadata';

import { AppModule } from './app.module';

async function bootstrap(): Promise<void> {
  const app = await NestFactory.create(AppModule);

  // Reject unknown fields and coerce types, so malformed clients fail loudly.
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
    }),
  );

  // The Flutter app is not browser-hosted in production, but CORS keeps the
  // Flutter-web build usable during development.
  app.enableCors({ origin: process.env.CORS_ORIGIN ?? '*' });

  const port = Number(process.env.PORT ?? 3000);
  await app.listen(port);
  // eslint-disable-next-line no-console
  console.log(`Caesar API listening on http://localhost:${port}`);
}

void bootstrap();
