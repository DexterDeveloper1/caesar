# Caesar

A fast, offline **brain-training game** built with Flutter. Answer quick
spelling and math challenges against the clock, keep your streak alive, and
beat your own highscore. No account, no network — it all runs on-device.

## Modes

- **Spelling** — a word flashes briefly, then disappears; retype it from
  memory. Recall (not recognition) is what actually exercises working memory,
  and unlike a single hidden letter it has exactly one correct answer.
- **Math** — solve generated arithmetic problems; difficulty ramps as you score.
- **Simon** — watch a growing color sequence and repeat it from memory.
- **N-Back** — a Dual N-Back working-memory task: each trial lights a grid cell
  and speaks a letter; flag when the position or the sound repeats from N steps
  back. Uses text-to-speech for the audio channel. **N adapts between sessions**
  — it rises above 85% accuracy and falls below 60%, keeping the task at the
  edge of your ability.

Spelling and Math are timed; three strikes ends the run. Simon runs until you
miss. N-Back runs a fixed set of trials and scores each channel (hits, misses,
false alarms).

### Difficulty

Levels are **earned, not incremented**: three correct answers in a row promote
you, one wrong answer steps you back down. That keeps the challenge tracking
actual skill (the "flow channel") instead of sprinting past it.

Math follows a banded curve rather than a straight ramp — each operation is
introduced on its own at a small size, then mixed with what came before, then
grown: addition within 10 → within 20 → subtraction joins → ranges grow →
×2–5 alone → mixed → ×2–10 → division (as the inverse of tables already
practised) → everything mixed. Operands are capped per band, so a run can no
longer leap from `1 + 1` to `98 × 79`.

Spelling draws from ~1,900 common nouns (via the MIT-licensed `english_words`
package) banded by length, dealt from a shuffle bag so a word cannot repeat
until its band is exhausted. N-Back adapts N between sessions.

## Tech stack

- **Flutter** (Dart) — targets Android, iOS, web, Windows, macOS, and Linux.
- **go_router** — declarative routing (see `lib/app/router.dart`).
- Material 3 theming (`lib/app/theme.dart`).

## Project structure

```
lib/
  app/            App shell: root widget, router, theme
  features/
    splash/       Launch screen
    home/         Landing + mode selection
    game/         Spelling & Math gameplay (generation, scoring, timer)
    simon/        Simon memory-sequence game
    nback/        Dual N-Back working-memory task (TTS audio)
    highscores/   Personal bests + global board
    leaderboard/  API client and state for online scores
    stats/        Streaks and lifetime session counts
    settings/     App settings
  core/           TrainingMode, constants, design tokens, shared widgets
  services/       Storage (shared_preferences), audio/haptics
assets/
  audio/          Music loop + sound effects (WAV)
server/           Optional NestJS leaderboard API (see server/README.md)
```

## Audio

Background music and sound effects are handled by `lib/services/audio_service.dart`
(built on `audioplayers`), with two independent toggles in Settings:

- **Sound effects** — correct/wrong/game-over/level-up stings, UI taps, and a
  distinct musical tone per Simon pad, plus haptics.
- **Background music** — one looping bed, played app-wide. It stops while the
  app is backgrounded and is silenced during N-Back so the spoken letters stay
  audible.

The shipped files in `assets/audio/` are simple synthesized placeholders. To use
your own audio, drop in replacements at the same paths (see the `Sfx` class for
the list); `.ogg` and `.mp3` also work and are much smaller than WAV.

## Getting started

Requires the Flutter SDK (3.44+ / Dart 3.12+).

```bash
flutter pub get
flutter run
```

## Development

```bash
flutter analyze   # static analysis / lints
flutter test      # unit + widget tests
```

## Roadmap

The app is being revived in phases:

- **Phase 0 — Stability** (done): fixed broken routing, the double-speed timer,
  and incorrect math generation; removed dead code; real tests.
- **Phase 1 — Architecture** (done): Riverpod state management, local
  persistence for highscores and settings, functional settings screen,
  difficulty selection.
- **Phase 2 — Polish** (done): sound/haptic feedback, accessibility semantics,
  stricter lints, CI (`.github/workflows/ci.yml`), wider test coverage.
- **Phase 3 — Online** (done): a NestJS backend for global leaderboards, plus
  an opt-in client in the app. See [server/README.md](server/README.md).

## Global leaderboards (optional)

The app is offline-first and fully playable with no server. Building with an
API URL additionally syncs new records and shows a global board:

```bash
flutter run --dart-define=CAESAR_API_URL=http://10.0.2.2:3000
```

(`10.0.2.2` is how the Android emulator reaches your machine's `localhost`.)
Without that define the app makes no network calls at all and the leaderboard
UI stays hidden. Players are identified by an anonymous, generated device id —
there are no accounts or passwords.

Run the API from [`server/`](server):

```bash
cd server && npm install && npm run start:dev
```
