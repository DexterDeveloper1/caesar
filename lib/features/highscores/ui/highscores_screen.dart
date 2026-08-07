import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:caesar/features/game/logic/game_type.dart';
import 'package:caesar/features/highscores/state/highscores_controller.dart';

/// Shows the best score per mode, backed by persisted storage.
class HighscoresScreen extends ConsumerWidget {
  const HighscoresScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scores = ref.watch(highscoresControllerProvider);
    final hasAny = scores.values.any((s) => s > 0);

    return Scaffold(
      appBar: AppBar(title: const Text('Highscores')),
      body: hasAny
          ? ListView(
              children: [
                for (final mode in GameType.values)
                  ListTile(
                    leading: Icon(_iconFor(mode)),
                    title: Text(mode.label),
                    trailing: Text(
                      '${scores[mode] ?? 0}',
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
              ],
            )
          : _EmptyState(theme: theme),
    );
  }

  IconData _iconFor(GameType mode) => switch (mode) {
    GameType.math => Icons.calculate,
    GameType.spelling => Icons.spellcheck,
  };
}

class _EmptyState extends StatelessWidget {
  final ThemeData theme;

  const _EmptyState({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.leaderboard_outlined,
            size: 72,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text('No highscores yet', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Play a round to set your first record.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
