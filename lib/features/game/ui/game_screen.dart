import 'dart:async';

import 'package:caesar/core/constants.dart';
import 'package:caesar/core/design.dart';
import 'package:caesar/core/training_mode.dart';
import 'package:caesar/core/widgets/juice.dart';
import 'package:caesar/features/game/logic/game_controller.dart';
import 'package:caesar/features/game/logic/game_type.dart';
import 'package:caesar/features/game/ui/results_view.dart';
import 'package:caesar/services/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GameScreen extends ConsumerStatefulWidget {
  final GameType mode;

  const GameScreen({super.key, required this.mode});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  final TextEditingController _controller = TextEditingController();

  /// Drives the brief green/red wash over the question card.
  Color? _flash;
  Timer? _flashTimer;

  TrainingMode get _trainingMode =>
      widget.mode == GameType.math ? TrainingMode.math : TrainingMode.spelling;

  @override
  void dispose() {
    _flashTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _showFlash(Color color) {
    setState(() => _flash = color);
    _flashTimer?.cancel();
    _flashTimer = Timer(Motion.normal, () {
      if (mounted) setState(() => _flash = null);
    });
  }

  void _submit() {
    if (_controller.text.trim().isEmpty) return;
    ref
        .read(gameControllerProvider(widget.mode).notifier)
        .submit(_controller.text);
    _controller.clear();
  }

  void _restart() {
    ref.read(gameControllerProvider(widget.mode).notifier).restart();
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(gameControllerProvider(widget.mode), (previous, next) {
      if (previous == null) return;
      final audio = ref.read(audioServiceProvider);
      if (next.isGameOver && !previous.isGameOver) {
        audio.gameOver();
      } else if (next.score > previous.score) {
        audio.correct();
        _showFlash(const Color(0xFF22C55E));
      } else if (next.strikes > previous.strikes) {
        audio.wrong();
        _showFlash(const Color(0xFFEF4444));
      }
    });

    final state = ref.watch(gameControllerProvider(widget.mode));
    final palette = AppPalette.of(context);
    final style = styleOf(_trainingMode);

    if (state.isGameOver) {
      return ResultsView(
        title: 'Game Over',
        mode: _trainingMode,
        score: state.score,
        scoreLabel: 'Final score',
        onRestart: _restart,
      );
    }

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(Insets.lg),
            child: Column(
              children: [
                _TopBar(mode: _trainingMode),
                const SizedBox(height: Insets.lg),

                // HUD: score, lives, and the countdown.
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SCORE',
                          style: TextStyle(
                            color: palette.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                        PopOnChange(
                          trigger: state.score,
                          child: CountUp(
                            value: state.score,
                            style: TextStyle(
                              color: palette.textPrimary,
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    LifePips(used: state.strikes, total: GameConfig.maxStrikes),
                    CountdownRing(
                      secondsLeft: state.timeLeft,
                      totalSeconds: state.totalTime,
                    ),
                  ],
                ),
                const Spacer(),

                // The question itself.
                ShakeOnChange(
                  trigger: state.strikes,
                  child: AnimatedContainer(
                    duration: Motion.fast,
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: Insets.xl,
                      horizontal: Insets.lg,
                    ),
                    decoration: BoxDecoration(
                      color: _flash?.withValues(alpha: 0.22) ?? palette.surface,
                      borderRadius: Radii.card,
                      border: Border.all(
                        color: _flash ?? palette.surfaceBorder,
                        width: _flash != null ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          widget.mode == GameType.math
                              ? 'Solve it'
                              : 'Fill the blank',
                          style: TextStyle(
                            color: palette.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: Insets.md),
                        PopOnChange(
                          trigger: state.prompt,
                          scale: 1.08,
                          child: Text(
                            state.prompt,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: palette.textPrimary,
                              fontSize: 42,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: Insets.lg),

                TextField(
                  controller: _controller,
                  autofocus: true,
                  textAlign: TextAlign.center,
                  keyboardType: widget.mode == GameType.math
                      ? TextInputType.number
                      : TextInputType.text,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Your answer',
                    hintStyle: TextStyle(color: palette.textMuted),
                    filled: true,
                    fillColor: palette.surface,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: Radii.card,
                      borderSide: BorderSide(color: palette.surfaceBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: Radii.card,
                      borderSide: BorderSide(color: style.accent, width: 2),
                    ),
                  ),
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: Insets.md),
                Pressable(
                  onPressed: _submit,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: Insets.md),
                    decoration: BoxDecoration(
                      gradient: style.gradient,
                      borderRadius: Radii.card,
                      boxShadow: [
                        BoxShadow(
                          color: style.end.withValues(alpha: 0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        'Submit',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Back control plus the mode's name, styled with the mode's accent.
class _TopBar extends StatelessWidget {
  final TrainingMode mode;

  const _TopBar({required this.mode});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final style = styleOf(mode);
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
          mode.label,
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
