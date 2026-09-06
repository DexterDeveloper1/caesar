import 'package:caesar/core/training_mode.dart';
import 'package:caesar/features/game/logic/game_type.dart';
import 'package:caesar/features/game/ui/game_screen.dart';
import 'package:caesar/features/game/ui/results_view.dart';
import 'package:caesar/features/highscores/ui/highscores_screen.dart';
import 'package:caesar/features/home/ui/home_screen.dart';
import 'package:caesar/features/nback/logic/nback_audio.dart';
import 'package:caesar/features/nback/ui/nback_screen.dart';
import 'package:caesar/features/settings/ui/settings_screen.dart';
import 'package:caesar/features/simon/ui/simon_screen.dart';
import 'package:caesar/services/storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Silent stand-in so N-Back never reaches the real TTS plugin in tests.
class _SilentNBackAudio implements NBackAudio {
  @override
  Future<void> speakLetter(String letter) async {}

  @override
  Future<void> dispose() async {}
}

/// Guards against RenderFlex overflows on small screens.
///
/// Every screen is pumped at a deliberately cramped phone size; any overflow
/// raises a Flutter error, which `tester.takeException` surfaces here.
void main() {
  /// A small-but-real device size (e.g. iPhone SE class) in logical pixels.
  const small = Size(320, 568);

  Future<void> pumpAt(
    WidgetTester tester,
    Widget child, {
    Size size = small,
  }) async {
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          nbackAudioProvider.overrideWithValue(_SilentNBackAudio()),
        ],
        child: MaterialApp(home: child),
      ),
    );
    await tester.pump();
  }

  void expectNoOverflow(WidgetTester tester, String screen) {
    final error = tester.takeException();
    expect(error, isNull, reason: '$screen overflows at $small: $error');
  }

  testWidgets('Home fits a small screen', (tester) async {
    await pumpAt(tester, const HomeScreen());
    await tester.pump(const Duration(seconds: 1));
    expectNoOverflow(tester, 'HomeScreen');
  });

  testWidgets('Math game fits a small screen', (tester) async {
    await pumpAt(tester, const GameScreen(mode: GameType.math));
    expectNoOverflow(tester, 'GameScreen');
  });

  testWidgets('Simon fits a small screen', (tester) async {
    await pumpAt(tester, const SimonScreen());
    await tester.pump(const Duration(seconds: 2));
    expectNoOverflow(tester, 'SimonScreen');
  });

  testWidgets('N-Back fits a small screen', (tester) async {
    await pumpAt(tester, const NBackScreen());
    await tester.pump(const Duration(milliseconds: 300));
    expectNoOverflow(tester, 'NBackScreen');
  });

  testWidgets('Results fits a small screen', (tester) async {
    await pumpAt(
      tester,
      ResultsView(
        title: 'Game Over',
        mode: TrainingMode.math,
        score: 12,
        scoreLabel: 'Final score',
        onRestart: () {},
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expectNoOverflow(tester, 'ResultsView');
  });

  testWidgets('Highscores fits a small screen', (tester) async {
    await pumpAt(tester, const HighscoresScreen());
    expectNoOverflow(tester, 'HighscoresScreen');
  });

  testWidgets('Settings fits a small screen', (tester) async {
    await pumpAt(tester, const SettingsScreen());
    expectNoOverflow(tester, 'SettingsScreen');
  });

  testWidgets('Math game fits with the keyboard open', (tester) async {
    // An on-screen keyboard eats roughly half the height of a small phone;
    // this is the case where the answer field and Submit button are tightest.
    tester.view.physicalSize = small * 3;
    tester.view.devicePixelRatio = 3.0;
    tester.view.viewInsets = const FakeViewPadding(bottom: 280 * 3);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const MaterialApp(home: GameScreen(mode: GameType.math)),
      ),
    );
    await tester.pump();

    expectNoOverflow(tester, 'GameScreen (keyboard open)');
  });
}
