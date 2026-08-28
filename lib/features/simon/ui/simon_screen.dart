import 'package:caesar/app/router.dart';
import 'package:caesar/features/simon/logic/simon_controller.dart';
import 'package:caesar/features/simon/logic/simon_state.dart';
import 'package:caesar/services/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SimonScreen extends ConsumerWidget {
  const SimonScreen({super.key});

  static const List<_Pad> _pads = [
    _Pad('Green', Color(0xFF2E7D32), Color(0xFF69F0AE)),
    _Pad('Red', Color(0xFFC62828), Color(0xFFFF8A80)),
    _Pad('Blue', Color(0xFF1565C0), Color(0xFF80D8FF)),
    _Pad('Yellow', Color(0xFFF9A825), Color(0xFFFFF59D)),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(simonControllerProvider, (previous, next) {
      if (previous == null) return;
      final audio = ref.read(audioServiceProvider);
      if (next.isGameOver && !previous.isGameOver) {
        audio.gameOver();
      } else if (next.level > previous.level) {
        audio.levelUp();
      } else if (next.activePad != null &&
          next.activePad != previous.activePad) {
        // Sound the pad as it lights up during playback, so the sequence can
        // be heard as well as seen.
        audio.simonPad(next.activePad!);
      }
    });

    final state = ref.watch(simonControllerProvider);
    final controller = ref.read(simonControllerProvider.notifier);

    if (state.isGameOver) {
      return _GameOverView(level: state.level, onRestart: controller.restart);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Simon'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              'Level ${state.level}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              state.status == SimonStatus.showing
                  ? 'Watch the sequence…'
                  : 'Your turn — repeat it',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: GridView.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      for (var i = 0; i < _pads.length; i++)
                        _PadButton(
                          pad: _pads[i],
                          lit: state.activePad == i,
                          enabled: state.acceptsInput,
                          onTap: () {
                            ref.read(audioServiceProvider).simonPad(i);
                            controller.onTap(i);
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pad {
  final String label;
  final Color base;
  final Color lit;

  const _Pad(this.label, this.base, this.lit);
}

class _PadButton extends StatelessWidget {
  final _Pad pad;
  final bool lit;
  final bool enabled;
  final VoidCallback onTap;

  const _PadButton({
    required this.pad,
    required this.lit,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: pad.label,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            color: lit ? pad.lit : pad.base,
            borderRadius: BorderRadius.circular(20),
            boxShadow: lit
                ? [BoxShadow(color: pad.lit, blurRadius: 24, spreadRadius: 2)]
                : null,
          ),
        ),
      ),
    );
  }
}

class _GameOverView extends StatelessWidget {
  final int level;
  final VoidCallback onRestart;

  const _GameOverView({required this.level, required this.onRestart});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.psychology_alt, size: 80),
            const SizedBox(height: 16),
            Text(
              'Game Over',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            Text('You reached level $level'),
            const SizedBox(height: 20),
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
    );
  }
}
