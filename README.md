# Caesar

A fast, offline **brain-training game** built with Flutter. Answer quick
spelling and math challenges against the clock, keep your streak alive, and
beat your own highscore. No account, no network — it all runs on-device.

## Modes

- **Spelling** — a letter is missing from a word; type it before time runs out.
- **Math** — solve generated arithmetic problems; difficulty ramps as you score.

Three strikes ends the run. Difficulty (and time pressure) increases with every
correct answer.

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
    game/         Core gameplay (question generation, scoring, timer)
    highscores/   Highscores board
    settings/     App settings
```

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
- **Phase 1 — Architecture**: Riverpod state management, local persistence for
  highscores and settings, functional settings screen, difficulty selection.
- **Phase 2 — Polish**: sound effects, accessibility, stricter lints, CI, wider
  test coverage.
- **Phase 3 — Online (optional)**: a NestJS backend for global leaderboards and
  accounts.
