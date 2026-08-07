import 'package:caesar/app/app.dart';
import 'package:caesar/features/game/logic/game_controller.dart';
import 'package:caesar/features/game/logic/game_state.dart';
import 'package:caesar/features/game/logic/game_type.dart';
import 'package:caesar/features/highscores/state/highscores_controller.dart';
import 'package:caesar/services/storage_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _container([Map<String, Object> seed = const {}]) async {
  SharedPreferences.setMockInitialValues(seed);
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

  group('GameType.fromString', () {
    test('parses known modes, falls back to spelling', () {
      expect(GameType.fromString('math'), GameType.math);
      expect(GameType.fromString('spelling'), GameType.spelling);
      expect(GameType.fromString('expert'), GameType.spelling);
      expect(GameType.fromString(null), GameType.spelling);
    });
  });

  group('GameController', () {
    test('starts in playing state', () async {
      final container = await _container();
      final state = container.read(gameControllerProvider(GameType.math));
      expect(state.status, GameStatus.playing);
      expect(state.score, 0);
      expect(state.strikes, 0);
      expect(state.prompt, isNotEmpty);
    });

    test('three wrong answers ends the game', () async {
      final container = await _container();
      final notifier =
          container.read(gameControllerProvider(GameType.math).notifier);

      for (var i = 0; i < 3; i++) {
        notifier.submit('___definitely-wrong___');
      }

      final state = container.read(gameControllerProvider(GameType.math));
      expect(state.status, GameStatus.gameOver);
      expect(state.strikes, 3);
    });

    test('restart returns to a fresh playing state', () async {
      final container = await _container();
      final notifier =
          container.read(gameControllerProvider(GameType.math).notifier);

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
      first.read(highscoresControllerProvider.notifier).submit(GameType.math, 7);
      first.dispose();

      final second = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(second.dispose);
      expect(second.read(highscoresControllerProvider)[GameType.math], 7);
    });
  });
}
