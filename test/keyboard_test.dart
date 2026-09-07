import 'package:caesar/core/widgets/game_keyboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Written before the implementation.
///
/// The in-app keyboard exists for two reasons the system keyboard cannot
/// satisfy: it has no ~250ms show/hide animation eating a running clock, and it
/// offers no autocorrect or predictive text — which on the system keyboard can
/// literally suggest the answer during a spelling round.
void main() {
  testWidgets('letter layout shows every letter of the alphabet', (
    tester,
  ) async {
    final pressed = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GameKeyboard(
            layout: KeyboardLayout.letters,
            accent: Colors.blue,
            onKey: pressed.add,
            onBackspace: () {},
            onSubmit: () {},
          ),
        ),
      ),
    );

    for (final letter in 'abcdefghijklmnopqrstuvwxyz'.split('')) {
      expect(
        find.text(letter.toUpperCase()),
        findsOneWidget,
        reason: 'missing key $letter',
      );
    }
  });

  testWidgets('digit layout shows 0-9 and no letters', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GameKeyboard(
            layout: KeyboardLayout.digits,
            accent: Colors.blue,
            onKey: (_) {},
            onBackspace: () {},
            onSubmit: () {},
          ),
        ),
      ),
    );

    for (var digit = 0; digit <= 9; digit++) {
      expect(find.text('$digit'), findsOneWidget);
    }
    expect(find.text('A'), findsNothing);
  });

  testWidgets('tapping a key reports the character', (tester) async {
    final pressed = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GameKeyboard(
            layout: KeyboardLayout.letters,
            accent: Colors.blue,
            onKey: pressed.add,
            onBackspace: () {},
            onSubmit: () {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('C'));
    await tester.tap(find.text('A'));
    await tester.tap(find.text('T'));
    expect(pressed, ['c', 'a', 't']);
  });

  testWidgets('backspace and submit fire their callbacks', (tester) async {
    var backspaces = 0;
    var submits = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GameKeyboard(
            layout: KeyboardLayout.letters,
            accent: Colors.blue,
            onKey: (_) {},
            onBackspace: () => backspaces++,
            onSubmit: () => submits++,
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.backspace_outlined));
    await tester.tap(find.byIcon(Icons.keyboard_return_rounded));
    expect(backspaces, 1);
    expect(submits, 1);
  });

  testWidgets('fits a small phone without overflowing', (tester) async {
    tester.view.physicalSize = const Size(320 * 3, 568 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              const Spacer(),
              GameKeyboard(
                layout: KeyboardLayout.letters,
                accent: Colors.blue,
                onKey: (_) {},
                onBackspace: () {},
                onSubmit: () {},
              ),
            ],
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
