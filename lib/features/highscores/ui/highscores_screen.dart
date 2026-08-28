import 'package:caesar/core/training_mode.dart';
import 'package:caesar/features/highscores/state/highscores_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shows the best score per mode, backed by persisted storage.
class HighscoresScreen extends ConsumerWidget {
  const HighscoresScreen({super.key});

  static IconData _iconFor(TrainingMode mode) => switch (mode) {
    TrainingMode.spelling => Icons.spellcheck,
    TrainingMode.math => Icons.calculate,
    TrainingMode.simon => Icons.grid_view,
    TrainingMode.nback => Icons.memory,
  };

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
                for (final mode in TrainingMode.values)
                  ListTile(
                    leading: Icon(_iconFor(mode)),
                    title: Text(mode.label),
                    subtitle: Text(mode.scoreLabel),
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
