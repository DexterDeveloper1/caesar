import 'package:caesar/app/app.dart';
import 'package:caesar/core/training_mode.dart';
import 'package:caesar/features/game/logic/game_controller.dart';
import 'package:caesar/features/game/logic/game_state.dart';
import 'package:caesar/features/game/logic/game_type.dart';
import 'package:caesar/features/game/logic/question_generator.dart';
import 'package:caesar/features/game/ui/game_screen.dart';
import 'package:caesar/features/highscores/state/highscores_controller.dart';
import 'package:caesar/features/nback/logic/nback_audio.dart';
import 'package:caesar/features/nback/logic/nback_controller.dart';
import 'package:caesar/features/nback/logic/nback_logic.dart';
import 'package:caesar/features/nback/logic/nback_state.dart';
import 'package:caesar/features/nback/ui/nback_screen.dart';
import 'package:caesar/features/settings/state/settings_controller.dart';
import 'package:caesar/features/simon/logic/simon_controller.dart';
import 'package:caesar/features/simon/ui/simon_screen.dart';
import 'package:caesar/services/audio_service.dart';
import 'package:caesar/services/storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Always returns the same question so tests can submit a known answer.
class _FixedGenerator extends QuestionGenerator {
  @override
  Question generate(GameType mode, int difficulty) =>
      const Question(prompt: '2 + 2 = ?', answer: '4');
}

/// No-op audio so N-Back tests never touch the real TTS plugin.
class _SilentNBackAudio implements NBackAudio {
  @override
  Future<void> speakLetter(String letter) async {}

  @override
  Future<void> dispose() async {}
}

Future<ProviderContainer> _container() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  testWidgets('App boots to splash, then routes to home', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const CaesarApp(),
      ),
    );
    await tester.pump();

    expect(find.text('Caesar'), findsOneWidget);
    expect(find.text('Train your brain the fun way!'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.text('Welcome to Caesar'), findsOneWidget);
    expect(find.text('Spelling'), findsOneWidget);
    expect(find.text('Math'), findsOneWidget);
    expect(find.text('Simon'), findsOneWidget);
  });

  testWidgets('Wrong answers drive the game to Game Over', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const MaterialApp(home: GameScreen(mode: GameType.math)),
      ),
    );
    await tester.pump();

    expect(find.text('Submit'), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      await tester.enterText(find.byType(TextField), 'definitely-wrong');
      await tester.tap(find.text('Submit'));
      await tester.pump();
    }

    expect(find.text('Game Over'), findsOneWidget);
    expect(find.text('Restart'), findsOneWidget);
  });

  testWidgets('Simon plays back a sequence then awaits input', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const MaterialApp(home: SimonScreen()),
      ),
    );
    await tester.pump();

    // Starts in the watch/playback phase.
    expect(find.text('Level 0'), findsOneWidget);
    expect(find.text('Watch the sequence…'), findsOneWidget);

    // After playback completes, control passes to the player.
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Your turn — repeat it'), findsOneWidget);
  });

  group('GameType.fromString', () {
    test('parses known modes, falls back to spelling', () {
      expect(GameType.fromString('math'), GameType.math);
      expect(GameType.fromString('spelling'), GameType.spelling);
      expect(GameType.fromString('expert'), GameType.spelling);
      expect(GameType.fromString(null), GameType.spelling);
    });
  });

  group('QuestionGenerator', () {
    test('math answers are always correct and non-negative', () {
      final generator = QuestionGenerator();
      for (var seed = 0; seed < 200; seed++) {
        for (var difficulty = 1; difficulty <= 6; difficulty++) {
          final q = generator.generate(GameType.math, difficulty);
          final value = int.parse(q.answer);
          expect(value, greaterThanOrEqualTo(0), reason: q.prompt);
          expect(_evaluate(q.prompt), value, reason: q.prompt);
        }
      }
    });

    test('spelling hides exactly one letter', () {
      final q = QuestionGenerator().generate(GameType.spelling, 1);
      expect(q.prompt.contains('_'), isTrue);
      expect(q.answer.length, 1);
    });
  });

  group('GameController', () {
    test('starts in a fresh playing state', () async {
      final container = await _container();
      final state = container.read(gameControllerProvider(GameType.math));
      expect(state.status, GameStatus.playing);
      expect(state.score, 0);
      expect(state.strikes, 0);
      expect(state.prompt, isNotEmpty);
    });

    test('a correct answer increases the score', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          gameControllerProvider(GameType.math).overrideWith(
            () => GameController(GameType.math, generator: _FixedGenerator()),
          ),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(
        gameControllerProvider(GameType.math).notifier,
      );

      notifier.submit('4');
      expect(container.read(gameControllerProvider(GameType.math)).score, 1);
      notifier.submit('  4  '); // trimmed, still correct
      expect(container.read(gameControllerProvider(GameType.math)).score, 2);
    });

    test('three wrong answers ends the game', () async {
      final container = await _container();
      final notifier = container.read(
        gameControllerProvider(GameType.math).notifier,
      );

      for (var i = 0; i < 3; i++) {
        notifier.submit('___definitely-wrong___');
      }

      final state = container.read(gameControllerProvider(GameType.math));
      expect(state.status, GameStatus.gameOver);
      expect(state.strikes, 3);
    });

    test('restart returns to a fresh playing state', () async {
      final container = await _container();
      final notifier = container.read(
        gameControllerProvider(GameType.math).notifier,
      );

      for (var i = 0; i < 3; i++) {
        notifier.submit('___wrong___');
      }
      expect(
        container.read(gameControllerProvider(GameType.math)).status,
        GameStatus.gameOver,
      );

      notifier.restart();
      final state = container.read(gameControllerProvider(GameType.math));
      expect(state.status, GameStatus.playing);
      expect(state.score, 0);
      expect(state.strikes, 0);
    });
  });

  group('HighscoresController', () {
    test('records a new best only when the score improves', () async {
      final container = await _container();
      final notifier = container.read(highscoresControllerProvider.notifier);

      expect(notifier.submit(TrainingMode.math, 5), isTrue);
      expect(
        container.read(highscoresControllerProvider)[TrainingMode.math],
        5,
      );

      expect(
        notifier.submit(TrainingMode.math, 3),
        isFalse,
      ); // not an improvement
      expect(
        container.read(highscoresControllerProvider)[TrainingMode.math],
        5,
      );

      expect(notifier.submit(TrainingMode.math, 9), isTrue);
      expect(
        container.read(highscoresControllerProvider)[TrainingMode.math],
        9,
      );
    });

    test('persists across a reload of the container', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final first = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      first
          .read(highscoresControllerProvider.notifier)
          .submit(TrainingMode.math, 7);
      first.dispose();

      final second = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(second.dispose);
      expect(second.read(highscoresControllerProvider)[TrainingMode.math], 7);
    });
  });

  group('evaluateSimonTap', () {
    test('advances on a correct non-final tap', () {
      expect(evaluateSimonTap([1, 2, 3], 0, 1), SimonTap.correct);
      expect(evaluateSimonTap([1, 2, 3], 1, 2), SimonTap.correct);
    });

    test('completes the round on the final correct tap', () {
      expect(evaluateSimonTap([1, 2, 3], 2, 3), SimonTap.roundComplete);
      expect(evaluateSimonTap([0], 0, 0), SimonTap.roundComplete);
    });

    test('fails on a wrong tap', () {
      expect(evaluateSimonTap([1, 2, 3], 0, 2), SimonTap.wrong);
      expect(evaluateSimonTap([1, 2, 3], 2, 0), SimonTap.wrong);
    });
  });

  group('Audio settings', () {
    test('sound and music default to on and persist independently', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final first = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      expect(first.read(settingsControllerProvider).soundEnabled, isTrue);
      expect(first.read(settingsControllerProvider).musicEnabled, isTrue);

      // Turn music off but leave sound effects on.
      first.read(settingsControllerProvider.notifier).setMusicEnabled(false);
      // Persistence is fire-and-forget; let the writes flush before reloading.
      await Future<void>.delayed(Duration.zero);
      first.dispose();

      final second = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(second.dispose);
      expect(second.read(settingsControllerProvider).musicEnabled, isFalse);
      expect(second.read(settingsControllerProvider).soundEnabled, isTrue);
    });

    test('AudioService is silent when the toggles are off', () {
      final service = AudioService(soundEnabled: false, musicEnabled: false);
      // With sound disabled these must be no-ops rather than throwing, even
      // with no audio backend available in tests.
      expect(service.correct, returnsNormally);
      expect(service.wrong, returnsNormally);
      expect(service.gameOver, returnsNormally);
      expect(service.tap, returnsNormally);
      expect(() => service.simonPad(0), returnsNormally);
    });
  });

  group('N-Back logic', () {
    test('isNBackMatch: first n trials never match', () {
      expect(isNBackMatch([3, 3, 3], 0, 2), isFalse);
      expect(isNBackMatch([3, 3, 3], 1, 2), isFalse);
    });

    test('isNBackMatch: compares against n steps back', () {
      // index 2 vs index 0
      expect(isNBackMatch([5, 1, 5], 2, 2), isTrue);
      expect(isNBackMatch([5, 1, 2], 2, 2), isFalse);
    });

    test('classifyResponse covers the full truth table', () {
      expect(classifyResponse(isMatch: true, pressed: true), TrialOutcome.hit);
      expect(
        classifyResponse(isMatch: true, pressed: false),
        TrialOutcome.miss,
      );
      expect(
        classifyResponse(isMatch: false, pressed: true),
        TrialOutcome.falseAlarm,
      );
      expect(
        classifyResponse(isMatch: false, pressed: false),
        TrialOutcome.correctRejection,
      );
    });

    test('channel score rewards hits and never goes negative', () {
      expect(channelScore(hits: 5, falseAlarms: 2), 3);
      expect(channelScore(hits: 1, falseAlarms: 4), 0);
    });

    test('ChannelStats.record accumulates outcomes', () {
      var stats = const ChannelStats();
      stats = stats.record(TrialOutcome.hit).record(TrialOutcome.hit);
      stats = stats.record(TrialOutcome.falseAlarm);
      stats = stats.record(TrialOutcome.miss);
      expect(stats.hits, 2);
      expect(stats.falseAlarms, 1);
      expect(stats.misses, 1);
      expect(stats.score, 1); // 2 hits - 1 false alarm
    });
  });

  testWidgets('N-Back runs through all trials and finishes', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          nbackAudioProvider.overrideWithValue(_SilentNBackAudio()),
        ],
        child: const MaterialApp(home: NBackScreen()),
      ),
    );
    await tester.pump();

    expect(find.textContaining('Trial 1 /'), findsOneWidget);

    // Each trial is stimulusOn + gap ≈ 3s; drive past the whole session.
    for (var i = 0; i < NBackController.totalTrials; i++) {
      await tester.pump(const Duration(seconds: 3));
    }
    await tester.pumpAndSettle();

    expect(find.text('Session complete'), findsOneWidget);
  });
}

/// Evaluates a generated math prompt like `12 ÷ 3 = ?` to its integer result.
int _evaluate(String prompt) {
  final expr = prompt.replaceAll(' = ?', '').trim();
  final parts = expr.split(' ');
  final a = int.parse(parts[0]);
  final op = parts[1];
  final b = int.parse(parts[2]);
  return switch (op) {
    '+' => a + b,
    '-' => a - b,
    '×' => a * b,
    '÷' => a ~/ b,
    _ => throw ArgumentError('Unknown op: $op'),
  };
}
