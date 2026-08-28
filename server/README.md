# Caesar API

Global leaderboard service for the Caesar brain-training app. Built with
**NestJS 11** and TypeScript.

The Flutter app works completely offline; this service is optional and only
adds *global* leaderboards on top of the local highscores.

## Running

```bash
npm install
npm run start:dev     # ts-node, http://localhost:3000
```

Production:

```bash
npm run build
npm start
```

Docker:

```bash
docker build -t caesar-api .
docker run -p 3000:3000 -v caesar-data:/data caesar-api
```

Configuration comes from the environment — see [.env.example](.env.example).

## Tests

```bash
npm test
```

12 end-to-end tests drive the real HTTP surface (ranking, per-mode scoping,
best-score retention, and input validation).

## API

All endpoints are versioned under `/v1`, except the health probe.

### `GET /health`

```json
{ "status": "ok", "uptime": 42 }
```

### `POST /v1/scores`

Submits a run. The server keeps only the device's **best** score per mode, so
re-submitting a worse score never lowers a record.

```json
{
  "deviceId": "a-url-safe-id",
  "displayName": "Ada",
  "mode": "math",
  "score": 42
}
```

`displayName` is optional (defaults to `Anonymous`). `mode` is one of
`spelling`, `math`, `simon`, `nback`.

Response:

```json
{ "best": 42, "improved": true, "rank": 1 }
```

### `GET /v1/leaderboard/:mode?limit=50&deviceId=...`

Top scores, highest first, ties broken by who got there first. When `deviceId`
is supplied, that player's row is marked with `"isYou": true`.

```json
[{ "rank": 1, "displayName": "Bob", "score": 77, "updatedAt": "..." }]
```

### `GET /v1/leaderboard/:mode/rank?deviceId=...`

```json
{ "rank": 4 }
```

Returns `0` when the device has no score in that mode.

## Design notes

**Identity.** Players are identified by an anonymous, client-generated
`deviceId` — no accounts, passwords, or personal data. This keeps the app
frictionless and avoids storing credentials.

**Storage.** `ScoresRepository` is an abstract class; the shipped
`FileScoresRepository` keeps scores in memory and mirrors them to a JSON file
(written atomically via a temp file + rename). It needs no database server or
native modules, which makes it ideal for a single instance. To scale out,
implement `ScoresRepository` against a real database and rebind it in
[`scores.module.ts`](src/scores/scores.module.ts) — nothing else changes.

**Validation.** A global `ValidationPipe` runs with `whitelist` and
`forbidNonWhitelisted`, so unknown fields are rejected rather than ignored.
Scores are bounded and device IDs must be url-safe.

## Known limitations

These are deliberate for a first cut, and worth closing before a public launch:

- **Scores are trusted.** A crafted HTTP request can submit any score within the
  allowed bounds. Meaningful anti-cheat needs server-side validation of the run
  (e.g. a signed session or replayable inputs), not just a bigger number check.
- **`deviceId` is spoofable**, so one player can occupy several rows, and a
  cleared app reinstall loses the old identity.
- **No rate limiting.** Add `@nestjs/throttler` before exposing this publicly.
- **Single instance only** while using the file store — concurrent instances
  would overwrite each other's data.
