import 'package:caesar/features/game/logic/game_type.dart';
import 'package:caesar/features/game/ui/game_screen.dart';
import 'package:caesar/features/highscores/ui/highscores_screen.dart';
import 'package:caesar/features/home/ui/home_screen.dart';
import 'package:caesar/features/nback/ui/nback_screen.dart';
import 'package:caesar/features/reader/ui/library_screen.dart';
import 'package:caesar/features/reader/ui/reader_screen.dart';
import 'package:caesar/features/settings/ui/settings_screen.dart';
import 'package:caesar/features/simon/ui/simon_screen.dart';
import 'package:caesar/features/splash/ui/splash_screen.dart';
import 'package:caesar/features/sudoku/ui/sudoku_screen.dart';
import 'package:caesar/features/vocabulary/ui/saved_words_screen.dart';
import 'package:go_router/go_router.dart';

/// Central route table for the app.
///
/// Path constants live in [Routes] so screens never hardcode raw strings.
class Routes {
  static const splash = '/';
  static const home = '/home';
  static const settings = '/settings';
  static const highscores = '/highscores';
  static const simon = '/simon';
  static const nback = '/nback';
  static const sudoku = '/sudoku';
  static const savedWords = '/words';
  static const library = '/reading';

  /// Reader route for one imported document.
  static String reader(String id) => '/reading/${Uri.encodeComponent(id)}';

  /// Game route takes a `mode` path parameter (`math` or `spelling`).
  static String game(String mode) => '/game/$mode';
}

final caesarRouter = GoRouter(
  initialLocation: Routes.splash,
  routes: [
    GoRoute(
      path: Routes.splash,
      name: 'splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: Routes.home,
      name: 'home',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/game/:mode',
      name: 'game',
      builder: (context, state) {
        final mode = GameType.fromString(state.pathParameters['mode']);
        return GameScreen(mode: mode);
      },
    ),
    GoRoute(
      path: Routes.simon,
      name: 'simon',
      builder: (context, state) => const SimonScreen(),
    ),
    GoRoute(
      path: Routes.nback,
      name: 'nback',
      builder: (context, state) => const NBackScreen(),
    ),
    GoRoute(
      path: Routes.sudoku,
      name: 'sudoku',
      builder: (context, state) => const SudokuScreen(),
    ),
    GoRoute(
      path: Routes.library,
      name: 'library',
      builder: (context, state) => const LibraryScreen(),
      routes: [
        GoRoute(
          path: ':id',
          name: 'reader',
          builder: (context, state) => ReaderScreen(
            documentId: Uri.decodeComponent(state.pathParameters['id'] ?? ''),
          ),
        ),
      ],
    ),
    GoRoute(
      path: Routes.savedWords,
      name: 'savedWords',
      builder: (context, state) => const SavedWordsScreen(),
    ),
    GoRoute(
      path: Routes.highscores,
      name: 'highscores',
      builder: (context, state) => const HighscoresScreen(),
    ),
    GoRoute(
      path: Routes.settings,
      name: 'settings',
      builder: (context, state) => const SettingsScreen(),
    ),
  ],
);
