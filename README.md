# Caesar

A fast, offline **brain-training game** built with Flutter. Answer quick
spelling and math challenges against the clock, keep your streak alive, and
beat your own highscore. No account, no network — it all runs on-device.

## Modes

- **Spelling** — a letter is missing from a word; type it before time runs out.
- **Math** — solve generated arithmetic problems; difficulty ramps as you score.
- **Simon** — watch a growing color sequence and repeat it from memory.
- **N-Back** — a Dual N-Back working-memory task: each trial lights a grid cell
  and speaks a letter; flag when the position or the sound repeats from N steps
  back. Uses text-to-speech for the audio channel.

Spelling and Math are timed; three strikes ends the run and difficulty rises
with every correct answer. Simon runs until you miss. N-Back runs a fixed set of
trials and scores each channel (hits, misses, false alarms).

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
    highscores/   Highscores board
    settings/     App settings
  core/           Shared enums (TrainingMode), constants, design tokens
  services/       Storage (shared_preferences), audio/haptics
assets/
  audio/          Music loop + sound effects (WAV)
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
- **Phase 3 — Online (planned)**: a NestJS backend for global leaderboards and
  accounts.
