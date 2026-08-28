import 'package:caesar/core/design.dart';
import 'package:caesar/core/training_mode.dart';
import 'package:caesar/core/widgets/juice.dart';
import 'package:caesar/features/highscores/state/highscores_controller.dart';
import 'package:caesar/features/leaderboard/data/leaderboard_api.dart';
import 'package:caesar/features/leaderboard/state/leaderboard_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Personal bests per mode, plus the global leaderboard when the app is built
/// with an API URL.
class HighscoresScreen extends ConsumerStatefulWidget {
  const HighscoresScreen({super.key});

  @override
  ConsumerState<HighscoresScreen> createState() => _HighscoresScreenState();
}

class _HighscoresScreenState extends ConsumerState<HighscoresScreen> {
  TrainingMode _globalMode = TrainingMode.math;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final scores = ref.watch(highscoresControllerProvider);
    final online = ref.watch(onlineEnabledProvider);
    final hasAny = scores.values.any((s) => s > 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Highscores'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: AppBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(Insets.lg),
            children: [
              Text(
                'YOUR BESTS',
                style: TextStyle(
                  color: palette.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: Insets.sm),
              if (!hasAny)
                GlassCard(
                  child: Row(
                    children: [
                      Icon(
                        Icons.leaderboard_outlined,
                        color: palette.textMuted,
                      ),
                      const SizedBox(width: Insets.sm),
                      Expanded(
                        child: Text(
                          'No highscores yet — play a round to set your first '
                          'record.',
                          style: TextStyle(color: palette.textMuted),
                        ),
                      ),
                    ],
                  ),
                )
              else
                for (final mode in TrainingMode.values) ...[
                  _PersonalRow(mode: mode, score: scores[mode] ?? 0),
                  const SizedBox(height: Insets.sm),
                ],
              if (online) ...[
                const SizedBox(height: Insets.lg),
                Text(
                  'GLOBAL LEADERBOARD',
                  style: TextStyle(
                    color: palette.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: Insets.sm),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final mode in TrainingMode.values)
                        Padding(
                          padding: const EdgeInsets.only(right: Insets.sm),
                          child: ChoiceChip(
                            label: Text(mode.label),
                            selected: _globalMode == mode,
                            onSelected: (_) =>
                                setState(() => _globalMode = mode),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: Insets.md),
                _GlobalBoard(mode: _globalMode),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PersonalRow extends StatelessWidget {
  final TrainingMode mode;
  final int score;

  const _PersonalRow({required this.mode, required this.score});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final style = styleOf(mode);
    return GlassCard(
      padding: const EdgeInsets.all(Insets.sm + 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: style.gradient,
              shape: BoxShape.circle,
            ),
            child: Icon(style.icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mode.label,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  mode.scoreLabel,
                  style: TextStyle(color: palette.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          CountUp(
            value: score,
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// Async global board — degrades to a quiet message if the server is
/// unreachable, since the app is offline-first.
class _GlobalBoard extends ConsumerWidget {
  final TrainingMode mode;

  const _GlobalBoard({required this.mode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final async = ref.watch(leaderboardProvider(mode));

    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(Insets.lg),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => GlassCard(
        child: Row(
          children: [
            Icon(Icons.cloud_off_rounded, color: palette.textMuted),
            const SizedBox(width: Insets.sm),
            Expanded(
              child: Text(
                'Leaderboard unavailable right now.',
                style: TextStyle(color: palette.textMuted),
              ),
            ),
          ],
        ),
      ),
      data: (entries) {
        if (entries.isEmpty) {
          return GlassCard(
            child: Text(
              'No global scores for ${mode.label} yet.',
              style: TextStyle(color: palette.textMuted),
            ),
          );
        }
        return GlassCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (final entry in entries)
                _GlobalRow(entry: entry, palette: palette),
            ],
          ),
        );
      },
    );
  }
}

class _GlobalRow extends StatelessWidget {
  final LeaderboardEntry entry;
  final AppPalette palette;

  const _GlobalRow({required this.entry, required this.palette});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.md,
        vertical: Insets.sm + 2,
      ),
      decoration: BoxDecoration(
        color: entry.isYou ? const Color(0x2234D399) : null,
        borderRadius: Radii.card,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '${entry.rank}',
              style: TextStyle(
                color: palette.textMuted,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Text(
              entry.isYou ? '${entry.displayName} (you)' : entry.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: palette.textPrimary,
                fontWeight: entry.isYou ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
          Text(
            '${entry.score}',
            style: TextStyle(
              color: palette.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
