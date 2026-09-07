import 'package:caesar/core/design.dart';
import 'package:caesar/core/widgets/juice.dart';
import 'package:caesar/features/vocabulary/data/definition_service.dart';
import 'package:caesar/features/vocabulary/logic/saved_word.dart';
import 'package:caesar/features/vocabulary/state/vocabulary_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The player's word shelf.
///
/// A definition is fetched the first time a word is expanded and then stored on
/// the device, so a word costs at most one request in its lifetime and the list
/// keeps working offline afterwards.
class SavedWordsScreen extends ConsumerWidget {
  const SavedWordsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final saved = ref.watch(savedWordsProvider);
    final words = [...saved.words]
      ..sort((a, b) => b.savedAt.compareTo(a.savedAt));

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              _TopBar(count: words.length),
              Expanded(
                child: words.isEmpty
                    ? const _EmptyState()
                    : ListView.separated(
                        padding: const EdgeInsets.all(Insets.md),
                        itemCount: words.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: Insets.sm),
                        itemBuilder: (context, i) => _WordTile(word: words[i]),
                      ),
              ),
              if (words.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Insets.md,
                    0,
                    Insets.md,
                    Insets.md,
                  ),
                  child: Text(
                    'Words are kept for '
                    '${SavedWords.retention.inDays} days.',
                    style: TextStyle(color: palette.textMuted, fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WordTile extends ConsumerStatefulWidget {
  final SavedWord word;

  const _WordTile({required this.word});

  @override
  ConsumerState<_WordTile> createState() => _WordTileState();
}

class _WordTileState extends ConsumerState<_WordTile> {
  bool _expanded = false;
  bool _loading = false;
  bool _failed = false;

  Future<void> _toggle() async {
    setState(() => _expanded = !_expanded);
    // Only ever fetch once: after that the definition lives on the device.
    if (!_expanded || widget.word.definition != null || _loading) return;

    setState(() {
      _loading = true;
      _failed = false;
    });
    final definition = await ref
        .read(definitionServiceProvider)
        .lookup(widget.word.word);
    if (!mounted) return;

    if (definition == null) {
      setState(() {
        _loading = false;
        _failed = true;
      });
      return;
    }
    ref
        .read(savedWordsProvider.notifier)
        .attachDefinition(widget.word.word, definition);
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    // Read the live copy so a freshly attached definition renders immediately.
    final current = ref
        .watch(savedWordsProvider)
        .words
        .firstWhere(
          (w) => w.word == widget.word.word,
          orElse: () => widget.word,
        );

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Pressable(
                  onPressed: _toggle,
                  child: Row(
                    children: [
                      Icon(
                        _expanded
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        size: 20,
                        color: palette.textMuted,
                      ),
                      const SizedBox(width: Insets.sm),
                      Text(
                        current.word,
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (current.definition != null) ...[
                        const SizedBox(width: Insets.sm),
                        Icon(
                          Icons.check_circle_rounded,
                          size: 14,
                          color: palette.textMuted,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Pressable(
                onPressed: () =>
                    ref.read(savedWordsProvider.notifier).remove(current.word),
                child: Padding(
                  padding: const EdgeInsets.all(Insets.xs),
                  child: Icon(
                    Icons.delete_outline_rounded,
                    size: 20,
                    color: palette.textMuted,
                  ),
                ),
              ),
            ],
          ),
          AnimatedCrossFade(
            duration: Motion.fast,
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: Insets.sm),
              child: _body(current, palette),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(SavedWord word, AppPalette palette) {
    if (word.definition != null) {
      return Text(
        word.definition!,
        style: TextStyle(color: palette.textPrimary, fontSize: 14, height: 1.4),
      );
    }
    if (_loading) {
      return Row(
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: Insets.sm),
          Text(
            'Looking up…',
            style: TextStyle(color: palette.textMuted, fontSize: 13),
          ),
        ],
      );
    }
    return Row(
      children: [
        Expanded(
          child: Text(
            _failed
                ? "Couldn't fetch a definition. Check your connection and "
                      'tap to retry.'
                : 'Tap again to look this up.',
            style: TextStyle(color: palette.textMuted, fontSize: 13),
          ),
        ),
        if (_failed)
          Pressable(
            onPressed: () {
              setState(() => _expanded = false);
              _toggle();
            },
            child: Icon(
              Icons.refresh_rounded,
              size: 18,
              color: palette.textMuted,
            ),
          ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Insets.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu_book_rounded, size: 64, color: palette.textMuted),
            const SizedBox(height: Insets.md),
            Text(
              'No saved words yet',
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: Insets.sm),
            Text(
              'Play a round of Spelling — afterwards you can keep any words '
              'you want to learn.',
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.textMuted, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final int count;

  const _TopBar({required this.count});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.all(Insets.md),
      child: Row(
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
          Text(
            'My words',
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          if (count > 0)
            Text(
              '$count',
              style: TextStyle(
                color: palette.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}
