import 'package:caesar/core/design.dart';
import 'package:caesar/features/vocabulary/state/vocabulary_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Post-round vocabulary review.
///
/// Words are captured silently while playing — a save button mid-round would
/// distract from a timed recall task and double as a pause. Here, afterwards,
/// the player picks which to keep. Words they got wrong are pre-selected,
/// because those are the ones actually worth learning.
class SessionWordsCard extends ConsumerStatefulWidget {
  const SessionWordsCard({super.key});

  @override
  ConsumerState<SessionWordsCard> createState() => _SessionWordsCardState();
}

class _SessionWordsCardState extends ConsumerState<SessionWordsCard> {
  bool _seeded = false;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final session = ref.watch(wordSessionProvider);
    final saved = ref.watch(savedWordsProvider);

    if (session.isEmpty) return const SizedBox.shrink();

    // Pre-select the missed words once, when the card first appears.
    if (!_seeded) {
      _seeded = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final controller = ref.read(savedWordsProvider.notifier);
        for (final word in session.suggested) {
          if (!ref.read(savedWordsProvider).contains(word)) {
            controller.toggle(word);
          }
        }
      });
    }

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.menu_book_rounded,
                size: 18,
                color: palette.textPrimary,
              ),
              const SizedBox(width: Insets.sm),
              Text(
                'Words from this round',
                style: TextStyle(
                  color: palette.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.xs),
          Text(
            'Tap to keep a word for later. Missed words are already selected.',
            style: TextStyle(color: palette.textMuted, fontSize: 12),
          ),
          const SizedBox(height: Insets.sm),
          Wrap(
            spacing: Insets.sm,
            runSpacing: Insets.sm,
            children: [
              for (final seen in session.words)
                _WordChip(
                  word: seen.word,
                  missed: !seen.wasCorrect,
                  kept: saved.contains(seen.word),
                  onTap: () =>
                      ref.read(savedWordsProvider.notifier).toggle(seen.word),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WordChip extends StatelessWidget {
  final String word;
  final bool missed;
  final bool kept;
  final VoidCallback onTap;

  const _WordChip({
    required this.word,
    required this.missed,
    required this.kept,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    const keepColour = Color(0xFF34D399);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.fast,
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.sm + 2,
          vertical: Insets.sm,
        ),
        decoration: BoxDecoration(
          color: kept
              ? keepColour.withValues(alpha: 0.22)
              : palette.surfaceBorder.withValues(alpha: 0.4),
          borderRadius: Radii.pill,
          border: Border.all(
            color: kept ? keepColour : palette.surfaceBorder,
            width: kept ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              kept ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
              size: 15,
              color: kept ? keepColour : palette.textMuted,
            ),
            const SizedBox(width: Insets.xs),
            Text(
              word,
              style: TextStyle(
                color: palette.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
                // A missed word is worth noticing.
                decoration: missed ? TextDecoration.underline : null,
                decorationColor: const Color(0xFFFB7185),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
