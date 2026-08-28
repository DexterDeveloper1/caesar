import 'package:caesar/app/router.dart';
import 'package:caesar/core/constants.dart';
import 'package:caesar/core/design.dart';
import 'package:caesar/core/training_mode.dart';
import 'package:caesar/core/widgets/juice.dart';
import 'package:caesar/features/highscores/state/highscores_controller.dart';
import 'package:caesar/features/stats/logic/streak_logic.dart';
import 'package:caesar/features/stats/state/stats_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Motion.slow,
  );

  static String _routeFor(TrainingMode mode) => switch (mode) {
    TrainingMode.spelling => Routes.game('spelling'),
    TrainingMode.math => Routes.game('math'),
    TrainingMode.simon => Routes.simon,
    TrainingMode.nback => Routes.nback,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _controller.forward());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<bool> _confirmExit() async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit Caesar?'),
        content: const Text('Are you sure you want to close the app?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Exit'),
          ),
        ],
      ),
    );
    return shouldExit ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final stats = ref.watch(statsControllerProvider);
    final scores = ref.watch(highscoresControllerProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldExit = await _confirmExit();
        if (!shouldExit || !context.mounted) return;
        Navigator.of(context).pop();
      },
      child: Scaffold(
        body: AppBackground(
          child: SafeArea(
            child: FadeTransition(
              opacity: _controller,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      Insets.lg,
                      Insets.md,
                      Insets.lg,
                      Insets.sm,
                    ),
                    sliver: SliverToBoxAdapter(child: _Header(stats: stats)),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Insets.lg,
                      vertical: Insets.sm,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: Text(
                        'Choose a workout',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: palette.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      Insets.lg,
                      Insets.sm,
                      Insets.lg,
                      Insets.md,
                    ),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: Insets.md,
                            crossAxisSpacing: Insets.md,
                            childAspectRatio: 0.82,
                          ),
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final mode = TrainingMode.values[index];
                        return _ModeCard(
                          mode: mode,
                          best: scores[mode] ?? 0,
                          animation: _controller,
                          order: index,
                          onTap: () => context.go(_routeFor(mode)),
                        );
                      }, childCount: TrainingMode.values.length),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      Insets.lg,
                      0,
                      Insets.lg,
                      Insets.lg,
                    ),
                    sliver: SliverToBoxAdapter(child: _Footer(stats: stats)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Greeting, streak, and the daily-goal indicator.
class _Header extends StatelessWidget {
  final PlayerStats stats;

  const _Header({required this.stats});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final theme = Theme.of(context);
    final done = trainedToday(stats, DateTime.now());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppInfo.name,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: palette.textPrimary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: Insets.xs),
                  Text(
                    'Sharpen your mind, one round at a time.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: palette.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Pressable(
              onPressed: () => context.push(Routes.settings),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: palette.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: palette.surfaceBorder),
                ),
                child: Icon(
                  Icons.settings_rounded,
                  color: palette.textPrimary,
                  size: 22,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: Insets.md),
        GlassCard(
          child: Row(
            children: [
              _Stat(
                icon: Icons.local_fire_department_rounded,
                tint: const Color(0xFFFB923C),
                value: stats.currentStreak,
                label: stats.currentStreak == 1 ? 'day streak' : 'day streak',
              ),
              _Divider(color: palette.surfaceBorder),
              _Stat(
                icon: Icons.fitness_center_rounded,
                tint: const Color(0xFF60A5FA),
                value: stats.gamesPlayed,
                label: 'sessions',
              ),
              _Divider(color: palette.surfaceBorder),
              _Stat(
                icon: Icons.emoji_events_rounded,
                tint: const Color(0xFFFBBF24),
                value: stats.bestStreak,
                label: 'best streak',
              ),
            ],
          ),
        ),
        const SizedBox(height: Insets.sm),
        Row(
          children: [
            Icon(
              done
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 18,
              color: done ? const Color(0xFF34D399) : palette.textMuted,
            ),
            const SizedBox(width: Insets.sm),
            Expanded(
              child: Text(
                done
                    ? "Today's training complete — nice work!"
                    : 'Play one round to keep your streak alive',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: done ? const Color(0xFF34D399) : palette.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  final Color color;

  const _Divider({required this.color});

  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 34, color: color);
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final Color tint;
  final int value;
  final String label;

  const _Stat({
    required this.icon,
    required this.tint,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: tint, size: 22),
          const SizedBox(height: Insets.xs),
          PopOnChange(
            trigger: value,
            child: CountUp(
              value: value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: palette.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: palette.textMuted),
          ),
        ],
      ),
    );
  }
}

/// A single game tile: colour-coded, showing the personal best for that mode.
class _ModeCard extends StatelessWidget {
  final TrainingMode mode;
  final int best;
  final Animation<double> animation;
  final int order;
  final VoidCallback onTap;

  const _ModeCard({
    required this.mode,
    required this.best,
    required this.animation,
    required this.order,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final style = styleOf(mode);
    // Stagger the cards in for a livelier entrance.
    final start = (0.1 * order).clamp(0.0, 0.6);
    final curved = CurvedAnimation(
      parent: animation,
      curve: Interval(start, 1, curve: Motion.emphasized),
    );

    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.12),
          end: Offset.zero,
        ).animate(curved),
        child: Pressable(
          onPressed: onTap,
          child: Container(
            padding: const EdgeInsets.all(Insets.sm + 4),
            decoration: BoxDecoration(
              gradient: style.gradient,
              borderRadius: Radii.card,
              boxShadow: [
                BoxShadow(
                  color: style.end.withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Color(0x33FFFFFF),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(style.icon, color: Colors.white, size: 22),
                ),
                const Spacer(),
                Text(
                  mode.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                // Flexible so a narrow tile drops the description rather than
                // overflowing.
                Flexible(
                  child: Text(
                    mode.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xE6FFFFFF),
                      fontSize: 11,
                      height: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: Insets.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Insets.sm,
                    vertical: 3,
                  ),
                  decoration: const BoxDecoration(
                    color: Color(0x33FFFFFF),
                    borderRadius: Radii.pill,
                  ),
                  child: Text(
                    best > 0 ? 'Best $best' : 'Not played',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  final PlayerStats stats;

  const _Footer({required this.stats});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Column(
      children: [
        Pressable(
          onPressed: () => context.push(Routes.highscores),
          child: GlassCard(
            child: Row(
              children: [
                Icon(
                  Icons.leaderboard_rounded,
                  color: palette.textPrimary,
                  size: 20,
                ),
                const SizedBox(width: Insets.sm),
                Expanded(
                  child: Text(
                    'Highscores',
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: palette.textMuted,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Insets.md),
        Text(
          'v${AppInfo.version}',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: palette.textMuted),
        ),
      ],
    );
  }
}
