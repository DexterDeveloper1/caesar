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

    // Spelling hides the word behind one slot per letter; the prompt carries
    // those slots, so the letter count comes from it.
    final slotCount = '•'.allMatches(state.prompt).length;
    final showSlots =
        widget.mode == GameType.spelling && !state.revealing && slotCount > 0;

    return QuitGuard(
      child: Scaffold(
        body: AppBackground(
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Keys shrink on short screens so the board always fits.
                final keyHeight = (constraints.maxHeight * 0.075).clamp(
                  30.0,
                  46.0,
                );
                return Padding(
                  padding: const EdgeInsets.all(Insets.md),
                  // A fixed column, not a scroll view: the keyboard is pinned to
                  // the bottom so it can never be pushed off-screen, and the
                  // question can never be scrolled out of sight.
                  child: Column(
                    children: [
                      _TopBar(mode: _trainingMode),
                      const SizedBox(height: Insets.md),

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
                                    fontSize: 30,
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
                              color: style.accent,
                            )
                          else
                            CountdownRing(
                              secondsLeft: state.timeLeft,
                              totalSeconds: state.totalTime,
                            ),
                        ],
                      ),

                      // Everything between the HUD and the keyboard flexes.
                      Expanded(
                        child: Center(
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ShakeOnChange(
                                  trigger: state.strikes,
                                  child: AnimatedContainer(
                                    duration: Motion.fast,
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: Insets.lg,
                                      horizontal: Insets.md,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          _flash?.withValues(alpha: 0.22) ??
                                          palette.surface,
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
                                        // Fixed height, scaled to fit: a long word
                                        // can no longer wrap and shove the rest of
                                        // the screen around.
                                        SizedBox(
                                          height: 76,
                                          child: Center(
                                            child: FittedBox(
                                              fit: BoxFit.scaleDown,
                                              child: showSlots
                                                  ? _LetterSlots(
                                                      count: slotCount,
                                                      typed: _input,
                                                      accent: style.accent,
                                                      palette: palette,
                                                    )
                                                  : PopOnChange(
                                                      trigger: state.prompt,
                                                      scale: 1.08,
                                                      child: Text(
                                                        state.prompt,
                                                        textAlign:
                                                            TextAlign.center,
                                                        style: TextStyle(
                                                          color: palette
                                                              .textPrimary,
                                                          fontSize: 42,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                          letterSpacing: 2,
                                                        ),
                                                      ),
                                                    ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                // Numbers still need a plain answer box; spelling
                                // shows the typed letters in the slots above.
                                if (!showSlots) ...[
                                  const SizedBox(height: Insets.md),
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
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: Insets.sm),
                      // Always-present keyboard: no show/hide animation eating the
                      // clock, and no autocorrect to leak the answer.
                      GameKeyboard(
                        layout: widget.mode == GameType.math
                            ? KeyboardLayout.digits
                            : KeyboardLayout.letters,
                        accent: style.accent,
                        keyHeight: keyHeight,
                        onKey: _type,
                        onBackspace: _backspace,
                        onSubmit: _submit,
                      ),
                    ],
                  ),
                );
              },
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

/// One box per letter of the hidden word, filling in as the player types.
///
/// The mask and the answer field used to be separate, which meant the length
/// hint told you nothing useful and a long word wrapped and shifted the page.
/// Merging them makes the length meaningful — it doubles as a progress
/// indicator — and the fixed layout above keeps it from moving anything.
class _LetterSlots extends StatelessWidget {
  final int count;
  final String typed;
  final Color accent;
  final AppPalette palette;

  const _LetterSlots({
    required this.count,
    required this.typed,
    required this.accent,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: AnimatedContainer(
              duration: Motion.instant,
              width: 40,
              height: 54,
              decoration: BoxDecoration(
                color: i < typed.length
                    ? accent.withValues(alpha: 0.18)
                    : palette.surfaceBorder.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: i < typed.length ? accent : palette.surfaceBorder,
                  width: i < typed.length ? 2 : 1,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                // Lower case, matching how the word was shown.
                i < typed.length ? typed[i] : '',
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
