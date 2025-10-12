import 'package:go_router/go_router.dart';
import 'package:caesar/features/home/ui/home_screen.dart';
import 'package:caesar/features/game/ui/game_screen.dart';
import 'package:caesar/features/settings/ui/settings_screen.dart';

final caesarRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      name: 'home',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/game/:mode',
      name: 'game',
      builder: (context, state) {
        final modeParam = state.pathParameters['mode'];
        final mode = modeParam == 'math'
            ? GameType.math
            : GameType.spelling; // default to spelling if unknown
        return GameScreen(mode: mode);
      },
    ),
    GoRoute(
      path: '/settings',
      name: 'settings',
      builder: (context, state) => const SettingsScreen(),
    ),
  ],
);
