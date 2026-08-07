import 'package:flutter/material.dart';

/// Placeholder highscores view.
///
/// Phase 1 wires this to persisted scores (via a storage service) so the
/// board shows real per-mode bests. For now it renders an honest empty state
/// instead of crashing on a missing route.
class HighscoresScreen extends StatelessWidget {
  const HighscoresScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Highscores')),
      body: Center(
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
      ),
    );
  }
}
