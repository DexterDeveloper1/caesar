import 'package:caesar/app/router.dart';
import 'package:caesar/features/nback/logic/nback_controller.dart';
import 'package:caesar/features/nback/logic/nback_state.dart';
import 'package:caesar/services/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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

    if (state.isFinished) {
      return _ResultsView(state: state, onRestart: controller.restart);
    }

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('N-Back'), centerTitle: true),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Text(
                'Trial ${state.trialNumber} / ${state.totalTrials}   ·   N = ${state.n}',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Tap a button when the position or the spoken letter '
                'repeats from ${state.n} steps back.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 20),
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: _Grid(activeCell: state.activeCell),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _ResponseButton(
                      label: 'Position',
                      icon: Icons.grid_view,
                      active: state.positionPressed,
                      onPressed: () {
                        ref.read(audioServiceProvider).tap();
                        controller.pressPosition();
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _ResponseButton(
                      label: 'Sound',
                      icon: Icons.volume_up,
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
    );
  }
}

class _Grid extends StatelessWidget {
  final int? activeCell;

  const _Grid({required this.activeCell});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GridView.count(
      crossAxisCount: 3,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (var i = 0; i < NBackController.gridSize; i++)
          DecoratedBox(
            decoration: BoxDecoration(
              color: activeCell == i
                  ? scheme.primary
                  : scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
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
    final child = Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [Icon(icon), const SizedBox(width: 8), Text(label)],
      ),
    );
    return active
        ? FilledButton(onPressed: onPressed, child: child)
        : FilledButton.tonal(onPressed: onPressed, child: child);
  }
}

class _ResultsView extends StatelessWidget {
  final NBackState state;
  final VoidCallback onRestart;

  const _ResultsView({required this.state, required this.onRestart});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('N-Back')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Session complete', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text('Score: ${state.score}', style: theme.textTheme.titleLarge),
              const SizedBox(height: 24),
              _ChannelResult(title: 'Position', stats: state.position),
              const SizedBox(height: 12),
              _ChannelResult(title: 'Sound', stats: state.audio),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: onRestart,
                child: const Text('Play again'),
              ),
              TextButton(
                onPressed: () => context.go(Routes.home),
                child: const Text('Back to Home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChannelResult extends StatelessWidget {
  final String title;
  final ChannelStats stats;

  const _ChannelResult({required this.title, required this.stats});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Hits ${stats.hits}   ·   Misses ${stats.misses}   ·   '
              'False alarms ${stats.falseAlarms}',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
