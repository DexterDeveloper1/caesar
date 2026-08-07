// Smoke and unit tests for the Caesar app.

import 'package:caesar/app/app.dart';
import 'package:caesar/features/game/ui/game_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App boots to the splash screen, then routes to home', (
    tester,
  ) async {
    await tester.pumpWidget(const CaesarApp());
    await tester.pump();

    // The splash screen shows the app name and tagline.
    expect(find.text('Caesar'), findsOneWidget);
    expect(find.text('Train your brain the fun way!'), findsOneWidget);

    // Let the splash timer fire and the home screen animate in.
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.text('Welcome to Caesar'), findsOneWidget);
    expect(find.text('Spelling Mode'), findsOneWidget);
    expect(find.text('Math Mode'), findsOneWidget);
  });

  group('GameType.fromString', () {
    test('parses known modes', () {
      expect(GameType.fromString('math'), GameType.math);
      expect(GameType.fromString('spelling'), GameType.spelling);
    });

    test('falls back to spelling for unknown or null input', () {
      expect(GameType.fromString('expert'), GameType.spelling);
      expect(GameType.fromString(null), GameType.spelling);
    });
  });
}
