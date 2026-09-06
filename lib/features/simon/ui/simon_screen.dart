import 'package:caesar/core/design.dart';
import 'package:caesar/core/training_mode.dart';
import 'package:caesar/core/widgets/juice.dart';
import 'package:caesar/core/widgets/quit_guard.dart';
import 'package:caesar/features/game/ui/results_view.dart';
import 'package:caesar/features/simon/logic/simon_controller.dart';
import 'package:caesar/features/simon/logic/simon_state.dart';
import 'package:caesar/services/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SimonScreen extends ConsumerWidget {
  const SimonScreen({super.key});

  static const List<_Pad> _pads = [
    _Pad('Green', Color(0xFF15803D), Color(0xFF4ADE80)),
    _Pad('Red', Color(0xFFB91C1C), Color(0xFFFB7185)),
    _Pad('Blue', Color(0xFF1D4ED8), Color(0xFF60A5FA)),
    _Pad('Yellow', Color(0xFFB45309), Color(0xFFFCD34D)),
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
    final palette = AppPalette.of(context);

    if (state.isGameOver) {
      return ResultsView(
        title: 'Sequence broken',
        mode: TrainingMode.simon,
        score: state.level,
        scoreLabel: 'Level reached',
        onRestart: controller.restart,
      );
    }

    final watching = state.status == SimonStatus.showing;

    return QuitGuard(
      message: 'This run will end and your level will not be saved.',
      child: Scaffold(
        body: AppBackground(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(Insets.lg),
              child: Column(
                children: [
                  _TopBar(),
                  const SizedBox(height: Insets.lg),
                  Text(
                    'LEVEL',
                    style: TextStyle(
                      color: palette.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                    ),
                  ),
                  PopOnChange(
                    trigger: state.level,
                    child: CountUp(
                      value: state.level,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 44,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                      ),
                    ),
                  ),
                  const SizedBox(height: Insets.sm),
                  // Clear status chip so the player always knows whose turn it is.
                  AnimatedContainer(
                    duration: Motion.fast,
                    height: 34,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: Insets.md),
                    decoration: BoxDecoration(
                      color: watching
                          ? const Color(0x332DD4BF)
                          : const Color(0x3334D399),
                      borderRadius: Radii.pill,
                      border: Border.all(color: palette.surfaceBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          watching
                              ? Icons.visibility_rounded
                              : Icons.touch_app_rounded,
                          size: 16,
                          color: palette.textPrimary,
                        ),
                        const SizedBox(width: Insets.sm),
                        // Flexible so the chip shrinks on narrow phones instead
                        // of overflowing.
                        Flexible(
                          child: Text(
                            watching
                                ? 'Watch the sequence…'
                                : 'Your turn — repeat it',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: palette.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Expanded so the square board shrinks to the available
                  // height instead of overflowing on short screens.
                  Expanded(
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: GridView.count(
                          crossAxisCount: 2,
                          mainAxisSpacing: Insets.md,
                          crossAxisSpacing: Insets.md,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            for (var i = 0; i < _pads.length; i++)
                              _PadButton(
                                pad: _pads[i],
                                lit: state.activePad == i,
                                watching: watching,
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
                  const SizedBox(height: Insets.md),
                  // Always occupies the same height: rendering this only during
                  // the input phase changed the column's height and made the
                  // whole board jump when the phase switched.
                  SizedBox(
                    height: 22,
                    child: AnimatedOpacity(
                      opacity: state.acceptsInput && state.sequence.isNotEmpty
                          ? 1
                          : 0,
                      duration: Motion.fast,
                      child: Text(
                        '${state.inputIndex} / ${state.sequence.length}',
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

  /// True while the sequence is being demonstrated.
  final bool watching;
  final bool enabled;
  final VoidCallback onTap;

  const _PadButton({
    required this.pad,
    required this.lit,
    required this.watching,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // During playback the un-lit pads recede slightly so the flashing one reads
    // as a spotlight. They are never greyed out — the board stays "on".
    final recede = watching && !lit;

    return Semantics(
      button: true,
      label: pad.label,
      child: Pressable(
        onPressed: enabled ? onTap : null,
        pressedScale: 0.93,
        dimWhenDisabled: false,
        child: AnimatedScale(
          // Lit pads swell; the others shrink a touch to deepen the contrast.
          scale: lit
              ? 1.06
              : recede
              ? 0.97
              : 1.0,
          duration: Motion.fast,
          curve: Motion.emphasized,
          child: AnimatedOpacity(
            opacity: recede ? 0.72 : 1.0,
            duration: Motion.fast,
            child: AnimatedContainer(
              duration: Motion.instant,
              decoration: BoxDecoration(
                color: lit ? pad.lit : pad.base,
                borderRadius: BorderRadius.circular(Radii.lg),
                border: Border.all(
                  color: lit ? Colors.white : const Color(0x1AFFFFFF),
                  width: lit ? 3 : 1,
                ),
                boxShadow: lit
                    ? [
                        BoxShadow(
                          color: pad.lit.withValues(alpha: 0.75),
                          blurRadius: 34,
                          spreadRadius: 4,
                        ),
                      ]
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final style = styleOf(TrainingMode.simon);
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
          'Simon',
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
