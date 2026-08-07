import 'package:caesar/app/app.dart';
import 'package:caesar/features/game/logic/game_controller.dart';
import 'package:caesar/features/game/logic/game_state.dart';
import 'package:caesar/features/game/logic/game_type.dart';
import 'package:caesar/features/game/logic/question_generator.dart';
import 'package:caesar/features/game/ui/game_screen.dart';
import 'package:caesar/features/highscores/state/highscores_controller.dart';
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
    expect(find.text('Spelling Mode'), findsOneWidget);
    expect(find.text('Math Mode'), findsOneWidget);
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

      expect(notifier.submit(GameType.math, 5), isTrue);
      expect(container.read(highscoresControllerProvider)[GameType.math], 5);

      expect(notifier.submit(GameType.math, 3), isFalse); // not an improvement
      expect(container.read(highscoresControllerProvider)[GameType.math], 5);

      expect(notifier.submit(GameType.math, 9), isTrue);
      expect(container.read(highscoresControllerProvider)[GameType.math], 9);
    });

    test('persists across a reload of the container', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final first = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      first
          .read(highscoresControllerProvider.notifier)
          .submit(GameType.math, 7);
      first.dispose();

      final second = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(second.dispose);
      expect(second.read(highscoresControllerProvider)[GameType.math], 7);
    });
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
