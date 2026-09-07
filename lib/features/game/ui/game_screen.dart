import 'dart:async';

import 'package:caesar/core/constants.dart';
import 'package:caesar/core/design.dart';
import 'package:caesar/core/training_mode.dart';
import 'package:caesar/core/widgets/game_keyboard.dart';
import 'package:caesar/core/widgets/juice.dart';
import 'package:caesar/core/widgets/quit_guard.dart';
import 'package:caesar/features/game/logic/game_controller.dart';
import 'package:caesar/features/game/logic/game_type.dart';
import 'package:caesar/features/game/ui/results_view.dart';
import 'package:caesar/features/vocabulary/ui/session_words_card.dart';
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
  /// The answer typed so far. Held here rather than in a TextField so no
  /// system keyboard is ever summoned.
  String _input = '';

  /// Drives the brief green/red wash over the question card.
  Color? _flash;
  Timer? _flashTimer;

  TrainingMode get _trainingMode =>
      widget.mode == GameType.math ? TrainingMode.math : TrainingMode.spelling;

  @override
  void dispose() {
    _flashTimer?.cancel();
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
    if (_input.trim().isEmpty) return;
    ref.read(gameControllerProvider(widget.mode).notifier).submit(_input);
    setState(() => _input = '');
  }

  void _restart() {
    ref.read(gameControllerProvider(widget.mode).notifier).restart();
    setState(() => _input = '');
  }

  void _type(String character) {
    if (ref.read(gameControllerProvider(widget.mode)).revealing) return;
    // Long enough for the longest word in the bank, with room to spare.
    if (_input.length >= 14) return;
    setState(() => _input += character);
  }

  void _backspace() {
    if (_input.isEmpty) return;
    setState(() => _input = _input.substring(0, _input.length - 1));
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
      if (next.prompt != previous.prompt && _input.isNotEmpty) {
        setState(() => _input = '');
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
        // Spelling collects the words you saw so you can keep any to learn.
        details: widget.mode == GameType.spelling
            ? const SessionWordsCard()
            : null,
      );
    }

    return QuitGuard(
      child: Scaffold(
        body: AppBackground(
          child: SafeArea(
            // Scrollable so the on-screen keyboard can never squeeze the answer
            // field and Submit button off the bottom.
            child: SingleChildScrollView(
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
                      LifePips(
                        used: state.strikes,
                        total: GameConfig.maxStrikes,
                      ),
                      if (state.revealing)
                        Icon(
                          Icons.visibility_rounded,
                          size: 30,
                          color: styleOf(_trainingMode).accent,
                        )
                      else
                        CountdownRing(
                          secondsLeft: state.timeLeft,
                          totalSeconds: state.totalTime,
                        ),
                    ],
                  ),
                  const SizedBox(height: Insets.xl),

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
                        color:
                            _flash?.withValues(alpha: 0.22) ?? palette.surface,
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
                                : state.revealing
                                ? 'Memorise it…'
                                : 'Type the word',
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

                  // Our own answer box: the typed text is state, not a
                  // TextField, so the system keyboard never opens.
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: Insets.md,
                      horizontal: Insets.md,
                    ),
                    decoration: BoxDecoration(
                      color: palette.surface,
                      borderRadius: Radii.card,
                      border: Border.all(
                        color: _input.isEmpty
                            ? palette.surfaceBorder
                            : style.accent,
                        width: _input.isEmpty ? 1 : 2,
                      ),
                    ),
                    child: Text(
                      _input.isEmpty ? 'Your answer' : _input,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _input.isEmpty
                            ? palette.textMuted
                            : palette.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: Insets.md),
                  // Always-present keyboard: no show/hide animation eating the
                  // clock, and no autocorrect to leak the answer.
                  GameKeyboard(
                    layout: widget.mode == GameType.math
                        ? KeyboardLayout.digits
                        : KeyboardLayout.letters,
                    accent: style.accent,
                    onKey: _type,
                    onBackspace: _backspace,
                    onSubmit: _submit,
                  ),
                  const SizedBox(height: Insets.xl),
                ],
              ),
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
