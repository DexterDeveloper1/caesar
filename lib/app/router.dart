import 'package:go_router/go_router.dart';
import 'package:caesar/features/splash/ui/splash_screen.dart';
import 'package:caesar/features/home/ui/home_screen.dart';
import 'package:caesar/features/game/ui/game_screen.dart';
import 'package:caesar/features/highscores/ui/highscores_screen.dart';
import 'package:caesar/features/settings/ui/settings_screen.dart';

/// Central route table for the app.
///
/// Path constants live in [Routes] so screens never hardcode raw strings.
class Routes {
  static const splash = '/';
  static const home = '/home';
  static const settings = '/settings';
  static const highscores = '/highscores';

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
