import 'package:caesar/app/router.dart';
import 'package:caesar/core/design.dart';
import 'package:caesar/core/training_mode.dart';
import 'package:caesar/core/widgets/juice.dart';
import 'package:caesar/features/highscores/state/highscores_controller.dart';
import 'package:caesar/features/stats/state/stats_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Shared end-of-run screen for every mode.
///
/// Celebrates a new personal best with a particle burst, and always shows the
/// streak so finishing a session feels like progress rather than a dead end.
class ResultsView extends ConsumerWidget {
  final String title;
  final TrainingMode mode;
  final int score;
  final String scoreLabel;
  final VoidCallback onRestart;

  /// Extra per-mode detail rendered under the score (e.g. N-Back channels).
  final Widget? details;

  const ResultsView({
    super.key,
    required this.title,
    required this.mode,
    required this.score,
    required this.scoreLabel,
    required this.onRestart,
    this.details,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final style = styleOf(mode);
    final best = ref.watch(highscoresControllerProvider)[mode] ?? 0;
    final stats = ref.watch(statsControllerProvider);
    // The score was already submitted, so matching the best means this run set
    // (or equalled) the record.
    final isRecord = score > 0 && score >= best;

    return Scaffold(
      body: AppBackground(
        child: Stack(
          children: [
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(Insets.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(Insets.md),
                        decoration: BoxDecoration(
                          gradient: style.gradient,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: style.end.withValues(alpha: 0.45),
                              blurRadius: 28,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Icon(
                          isRecord ? Icons.emoji_events_rounded : style.icon,
                          size: 44,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: Insets.lg),
                      Text(
                        isRecord ? 'New record!' : title,
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: Insets.xs),
                      Text(
                        scoreLabel,
                        style: TextStyle(
                          color: palette.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: Insets.sm),
                      CountUp(
                        value: score,
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontSize: 64,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: Insets.lg),
                      GlassCard(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _MiniStat(
                              icon: Icons.military_tech_rounded,
                              label: 'Best',
                              value: '$best',
                            ),
                            _MiniStat(
                              icon: Icons.local_fire_department_rounded,
                              label: 'Streak',
                              value: '${stats.currentStreak}',
                            ),
                            _MiniStat(
                              icon: Icons.fitness_center_rounded,
                              label: 'Sessions',
                              value: '${stats.gamesPlayed}',
                            ),
                          ],
                        ),
                      ),
                      if (details != null) ...[
                        const SizedBox(height: Insets.md),
                        details!,
                      ],
                      const SizedBox(height: Insets.xl),
                      Pressable(
                        onPressed: onRestart,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            vertical: Insets.md,
                          ),
                          decoration: BoxDecoration(
                            gradient: style.gradient,
                            borderRadius: Radii.card,
                          ),
                          child: const Center(
                            child: Text(
                              'Play again',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: Insets.sm),
                      Pressable(
                        onPressed: () => context.go(Routes.home),
                        child: Padding(
                          padding: const EdgeInsets.all(Insets.sm),
                          child: Text(
                            'Back to Home',
                            style: TextStyle(
                              color: palette.textMuted,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Celebration sits above the content but ignores input.
            if (isRecord) const Positioned.fill(child: Burst(play: true)),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MiniStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Column(
      children: [
        Icon(icon, size: 20, color: palette.textMuted),
        const SizedBox(height: Insets.xs),
        Text(
          value,
          style: TextStyle(
            color: palette.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(label, style: TextStyle(color: palette.textMuted, fontSize: 11)),
      ],
    );
  }
}
