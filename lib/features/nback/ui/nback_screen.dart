import 'package:caesar/core/design.dart';
import 'package:caesar/core/training_mode.dart';
import 'package:caesar/core/widgets/juice.dart';
import 'package:caesar/features/game/ui/results_view.dart';
import 'package:caesar/features/nback/logic/nback_controller.dart';
import 'package:caesar/features/nback/logic/nback_state.dart';
import 'package:caesar/services/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NBackScreen extends ConsumerStatefulWidget {
  const NBackScreen({super.key});

  @override
  ConsumerState<NBackScreen> createState() => _NBackScreenState();
}

class _NBackScreenState extends ConsumerState<NBackScreen> {
  /// Cached because `ref` cannot be used once the widget is being unmounted,
  /// and the music has to be un-ducked in [dispose].
  AudioService? _audio;

  @override
  void initState() {
    super.initState();
    // The spoken letters are the game mechanic here, so silence the music bed
    // for the duration of the session.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _audio?.duckMusic(ducked: true);
    });
  }

  @override
  void dispose() {
    _audio?.duckMusic(ducked: false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Keep the cached service current if the audio settings change.
    _audio = ref.watch(audioServiceProvider);

    final state = ref.watch(nbackControllerProvider);
    final controller = ref.read(nbackControllerProvider.notifier);
    final palette = AppPalette.of(context);
    final style = styleOf(TrainingMode.nback);

    if (state.isFinished) {
      return ResultsView(
        title: 'Session complete',
        mode: TrainingMode.nback,
        score: state.score,
        scoreLabel: 'Total score',
        onRestart: controller.restart,
        details: Row(
          children: [
            Expanded(
              child: _ChannelCard(title: 'Position', stats: state.position),
            ),
            const SizedBox(width: Insets.sm),
            Expanded(
              child: _ChannelCard(title: 'Sound', stats: state.audio),
            ),
          ],
        ),
      );
    }

    final progress = state.totalTrials == 0
        ? 0.0
        : state.trialNumber / state.totalTrials;

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(Insets.lg),
            child: Column(
              children: [
                _TopBar(),
                const SizedBox(height: Insets.md),

                // Session progress + the N level.
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TRIAL ${state.trialNumber} / ${state.totalTrials}',
                            style: TextStyle(
                              color: palette.textMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: Insets.sm),
                          ClipRRect(
                            borderRadius: Radii.pill,
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: progress),
                              duration: Motion.normal,
                              curve: Motion.emphasized,
                              builder: (context, v, _) =>
                                  LinearProgressIndicator(
                                    value: v,
                                    minHeight: 8,
                                    backgroundColor: palette.surfaceBorder,
                                    valueColor: AlwaysStoppedAnimation(
                                      style.accent,
                                    ),
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: Insets.md),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Insets.md,
                        vertical: Insets.sm,
                      ),
                      decoration: BoxDecoration(
                        gradient: style.gradient,
                        borderRadius: Radii.pill,
                      ),
                      child: Text(
                        'N = ${state.n}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Insets.md),
                Text(
                  'Tap when the position or the spoken letter repeats '
                  'from ${state.n} steps back.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: palette.textMuted, fontSize: 12),
                ),
                // Expanded so the square grid shrinks to the available height
                // instead of overflowing on short screens.
                Expanded(
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: _Grid(activeCell: state.activeCell, style: style),
                    ),
                  ),
                ),
                const SizedBox(height: Insets.md),
                Row(
                  children: [
                    Expanded(
                      child: _ResponseButton(
                        label: 'Position',
                        icon: Icons.grid_view_rounded,
                        active: state.positionPressed,
                        onPressed: () {
                          ref.read(audioServiceProvider).tap();
                          controller.pressPosition();
                        },
                      ),
                    ),
                    const SizedBox(width: Insets.md),
                    Expanded(
                      child: _ResponseButton(
                        label: 'Sound',
                        icon: Icons.volume_up_rounded,
                        active: state.audioPressed,
                        onPressed: () {
                          ref.read(audioServiceProvider).tap();
                          controller.pressAudio();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Grid extends StatelessWidget {
  final int? activeCell;
  final ModeStyle style;

  const _Grid({required this.activeCell, required this.style});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return GridView.count(
      crossAxisCount: 3,
      mainAxisSpacing: Insets.sm + 2,
      crossAxisSpacing: Insets.sm + 2,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (var i = 0; i < NBackController.gridSize; i++)
          AnimatedScale(
            scale: activeCell == i ? 1.06 : 1.0,
            duration: Motion.instant,
            curve: Motion.emphasized,
            child: AnimatedContainer(
              duration: Motion.instant,
              decoration: BoxDecoration(
                gradient: activeCell == i ? style.gradient : null,
                color: activeCell == i ? null : palette.surface,
                borderRadius: BorderRadius.circular(Radii.sm),
                border: Border.all(
                  color: activeCell == i
                      ? Colors.white24
                      : palette.surfaceBorder,
                ),
                boxShadow: activeCell == i
                    ? [
                        BoxShadow(
                          color: style.end.withValues(alpha: 0.6),
                          blurRadius: 24,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
            ),
          ),
      ],
    );
  }
}

class _ResponseButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onPressed;

  const _ResponseButton({
    required this.label,
    required this.icon,
    required this.active,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final style = styleOf(TrainingMode.nback);
    return Pressable(
      onPressed: onPressed,
      child: AnimatedContainer(
        duration: Motion.fast,
        padding: const EdgeInsets.symmetric(vertical: Insets.md + 2),
        decoration: BoxDecoration(
          gradient: active ? style.gradient : null,
          color: active ? null : palette.surface,
          borderRadius: Radii.card,
          border: Border.all(
            color: active ? Colors.white24 : palette.surfaceBorder,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: active ? Colors.white : palette.textPrimary,
            ),
            const SizedBox(width: Insets.sm),
            Text(
              label,
              style: TextStyle(
                color: active ? Colors.white : palette.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChannelCard extends StatelessWidget {
  final String title;
  final ChannelStats stats;

  const _ChannelCard({required this.title, required this.stats});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return GlassCard(
      padding: const EdgeInsets.all(Insets.sm + 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: palette.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: Insets.xs),
          _StatLine(
            label: 'Hits',
            value: stats.hits,
            tint: const Color(0xFF34D399),
          ),
          _StatLine(
            label: 'Misses',
            value: stats.misses,
            tint: palette.textMuted,
          ),
          _StatLine(
            label: 'False alarms',
            value: stats.falseAlarms,
            tint: const Color(0xFFFB7185),
          ),
        ],
      ),
    );
  }
}

class _StatLine extends StatelessWidget {
  final String label;
  final int value;
  final Color tint;

  const _StatLine({
    required this.label,
    required this.value,
    required this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: palette.textMuted, fontSize: 12)),
          Text(
            '$value',
            style: TextStyle(
              color: tint,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final style = styleOf(TrainingMode.nback);
    return Row(
      children: [
        Pressable(
          onPressed: () => Navigator.of(context).maybePop(),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: palette.surface,
              shape: BoxShape.circle,
              border: Border.all(color: palette.surfaceBorder),
            ),
            child: Icon(
              Icons.arrow_back_rounded,
              color: palette.textPrimary,
              size: 20,
            ),
          ),
        ),
        const SizedBox(width: Insets.md),
        Icon(style.icon, color: style.accent, size: 20),
        const SizedBox(width: Insets.sm),
        Text(
          'N-Back',
          style: TextStyle(
            color: palette.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
