import { ValidationPipe } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication } from '@nestjs/common';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import request from 'supertest';

import { AppModule } from '../src/app.module';

/**
 * End-to-end coverage of the leaderboard API, driven through real HTTP.
 * Each run gets its own temp data file so tests never share state.
 */
describe('Scores API (e2e)', () => {
  let app: INestApplication;
  let dataDir: string;

  const deviceA = 'device-aaaaaaa1';
  const deviceB = 'device-bbbbbbb2';

  beforeEach(async () => {
    dataDir = mkdtempSync(join(tmpdir(), 'caesar-test-'));

    const moduleRef: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    })
      .overrideProvider(ConfigService)
      .useValue({
        get: (key: string) =>
          key === 'DATA_FILE' ? join(dataDir, 'scores.json') : undefined,
      })
      .compile();

    app = moduleRef.createNestApplication();
    app.useGlobalPipes(
      new ValidationPipe({
        whitelist: true,
        forbidNonWhitelisted: true,
        transform: true,
      }),
    );
    await app.init();
  });

  afterEach(async () => {
    await app.close();
    rmSync(dataDir, { recursive: true, force: true });
  });

  const submit = (body: Record<string, unknown>) =>
    request(app.getHttpServer()).post('/v1/scores').send(body);

  it('reports health', async () => {
    const res = await request(app.getHttpServer()).get('/health').expect(200);
    expect(res.body.status).toBe('ok');
  });

  it('accepts a score and ranks it first', async () => {
    const res = await submit({
      deviceId: deviceA,
      displayName: 'Ada',
      mode: 'math',
      score: 12,
    }).expect(201);

    expect(res.body).toMatchObject({ best: 12, improved: true, rank: 1 });
  });

  it('keeps the higher score when a worse one is submitted', async () => {
    await submit({ deviceId: deviceA, mode: 'math', score: 20 }).expect(201);
    const res = await submit({
      deviceId: deviceA,
      mode: 'math',
      score: 5,
    }).expect(201);

    expect(res.body.best).toBe(20);
    expect(res.body.improved).toBe(false);
  });

  it('orders the leaderboard by score and flags the caller', async () => {
    await submit({ deviceId: deviceA, displayName: 'Ada', mode: 'simon', score: 4 });
    await submit({ deviceId: deviceB, displayName: 'Bob', mode: 'simon', score: 9 });

    const res = await request(app.getHttpServer())
      .get(`/v1/leaderboard/simon?deviceId=${deviceA}`)
      .expect(200);

    expect(res.body).toHaveLength(2);
    expect(res.body[0]).toMatchObject({ rank: 1, displayName: 'Bob', score: 9 });
    expect(res.body[1]).toMatchObject({ rank: 2, displayName: 'Ada', isYou: true });
  });

  it('scopes scores per mode', async () => {
    await submit({ deviceId: deviceA, mode: 'math', score: 30 });

    const simon = await request(app.getHttpServer())
      .get('/v1/leaderboard/simon')
      .expect(200);
    expect(simon.body).toHaveLength(0);
  });

  it('defaults a missing display name to Anonymous', async () => {
    await submit({ deviceId: deviceA, mode: 'nback', score: 3 });
    const res = await request(app.getHttpServer())
      .get('/v1/leaderboard/nback')
      .expect(200);
    expect(res.body[0].displayName).toBe('Anonymous');
  });

  it('returns a rank of 0 for an unknown device', async () => {
    const res = await request(app.getHttpServer())
      .get(`/v1/leaderboard/math/rank?deviceId=${deviceB}`)
      .expect(200);
    expect(res.body.rank).toBe(0);
  });

  describe('validation', () => {
    it('rejects an unknown mode', async () => {
      await request(app.getHttpServer())
        .get('/v1/leaderboard/chess')
        .expect(400);
    });

    it('rejects a negative score', async () => {
      await submit({ deviceId: deviceA, mode: 'math', score: -1 }).expect(400);
    });

    it('rejects an implausible score', async () => {
      await submit({
        deviceId: deviceA,
        mode: 'math',
        score: 999_999_999,
      }).expect(400);
    });

    it('rejects a malformed device id', async () => {
      await submit({ deviceId: 'no', mode: 'math', score: 1 }).expect(400);
    });

    it('rejects unknown fields', async () => {
      await submit({
        deviceId: deviceA,
        mode: 'math',
        score: 1,
        isAdmin: true,
      }).expect(400);
    });
  });
});
