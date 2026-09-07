import 'package:caesar/core/design.dart';
import 'package:caesar/core/widgets/juice.dart';
import 'package:caesar/features/reader/state/library_controller.dart';
import 'package:caesar/features/vocabulary/state/vocabulary_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The reading surface.
///
/// The point of this screen is that the text is *comfortable*: one column, a
/// measure of roughly 60 characters, generous line height, adjustable size, and
/// no pinch-zooming. Tapping a word saves it to the same vocabulary list the
/// Spelling game uses, so reading feeds the rest of the app.
class ReaderScreen extends ConsumerStatefulWidget {
  final String documentId;

  const ReaderScreen({super.key, required this.documentId});

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  final ScrollController _scroll = ScrollController();
  final Map<int, GlobalKey> _keys = {};
  bool _controlsOpen = false;
  bool _restored = false;

  @override
  void dispose() {
    _saveProgress();
    _scroll.dispose();
    super.dispose();
  }

  /// Records the topmost visible paragraph so reopening resumes in place.
  void _saveProgress() {
    if (!_scroll.hasClients) return;
    final offset = _scroll.offset;
    var topmost = 0;
    for (final entry in _keys.entries) {
      final context = entry.value.currentContext;
      if (context == null) continue;
      final box = context.findRenderObject() as RenderBox?;
      if (box == null) continue;
      final position = box.localToGlobal(Offset.zero).dy;
      if (position <= 120) topmost = entry.key;
    }
    if (offset <= 0) topmost = 0;
    ref.read(libraryProvider.notifier).saveProgress(widget.documentId, topmost);
  }

  void _onWordTap(String word) {
    final cleaned = word
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z-]'), '')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    if (cleaned.length < 3) return;

    ref.read(savedWordsProvider.notifier).toggle(cleaned);
    final kept = ref.read(savedWordsProvider).contains(cleaned);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(milliseconds: 1400),
          content: Text(
            kept ? 'Saved "$cleaned" to My words' : 'Removed "$cleaned"',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final fontSize = ref.watch(readerFontSizeProvider);
    final document = ref.watch(libraryProvider).byId(widget.documentId);

    if (document == null) {
      return const Scaffold(body: Center(child: Text('Document not found')));
    }

    // Jump to where reading stopped, once, after the first layout.
    if (!_restored) {
      _restored = true;
      final target = document.progressParagraph;
      if (target > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final key = _keys[target];
          final ctx = key?.currentContext;
          if (ctx != null) {
            Scrollable.ensureVisible(ctx, duration: Motion.normal);
          }
        });
      }
    }

    return PopScope(
      onPopInvokedWithResult: (didPop, result) => _saveProgress(),
      child: Scaffold(
        body: AppBackground(
          child: SafeArea(
            child: Column(
              children: [
                _TopBar(
                  title: document.title,
                  progress: document.progress,
                  onToggleControls: () =>
                      setState(() => _controlsOpen = !_controlsOpen),
                ),
                if (_controlsOpen)
                  _TypeControls(
                    size: fontSize,
                    onChanged: (v) =>
                        ref.read(readerFontSizeProvider.notifier).set(v),
                  ),
                Expanded(
                  child: NotificationListener<ScrollEndNotification>(
                    onNotification: (_) {
                      _saveProgress();
                      return false;
                    },
                    child: ListView.builder(
                      controller: _scroll,
                      // A comfortable measure: roughly 60 characters per line
                      // rather than edge-to-edge text.
                      padding: const EdgeInsets.symmetric(
                        horizontal: Insets.lg,
                        vertical: Insets.md,
                      ),
                      itemCount: document.paragraphs.length + 1,
                      itemBuilder: (context, index) {
                        if (index == document.paragraphs.length) {
                          return const SizedBox(height: 80);
                        }
                        final key = _keys.putIfAbsent(index, GlobalKey.new);
                        return Padding(
                          key: key,
                          padding: const EdgeInsets.only(bottom: Insets.md),
                          child: _Paragraph(
                            text: document.paragraphs[index],
                            fontSize: fontSize,
                            colour: palette.textPrimary,
                            onWordTap: _onWordTap,
                          ),
                        );
                      },
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

/// One paragraph, with every word individually tappable.
///
/// Built from a [Wrap] of per-word tap targets rather than a rich-text span
/// with gesture recognisers: recognisers would need disposing per word, and a
/// long book would create thousands of them.
class _Paragraph extends StatelessWidget {
  final String text;
  final double fontSize;
  final Color colour;
  final ValueChanged<String> onWordTap;

  const _Paragraph({
    required this.text,
    required this.fontSize,
    required this.colour,
    required this.onWordTap,
  });

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: colour,
      fontSize: fontSize,
      // Generous leading is the single biggest readability win on a phone.
      height: 1.55,
      letterSpacing: 0.1,
    );

    return Wrap(
      spacing: fontSize * 0.28,
      runSpacing: fontSize * 0.55,
      children: [
        for (final word in text.split(RegExp(r'\s+')))
          if (word.isNotEmpty)
            GestureDetector(
              onTap: () => onWordTap(word),
              behavior: HitTestBehavior.opaque,
              child: Text(word, style: style),
            ),
      ],
    );
  }
}

class _TypeControls extends StatelessWidget {
  final double size;
  final ValueChanged<double> onChanged;

  const _TypeControls({required this.size, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.md, 0, Insets.md, Insets.sm),
      child: GlassCard(
        child: Row(
          children: [
            Text('A', style: TextStyle(color: palette.textMuted, fontSize: 13)),
            Expanded(
              child: Slider(
                value: size,
                min: ReaderFontSizeController.min,
                max: ReaderFontSizeController.max,
                divisions:
                    (ReaderFontSizeController.max -
                            ReaderFontSizeController.min)
                        .round(),
                label: size.round().toString(),
                onChanged: onChanged,
              ),
            ),
            Text('A', style: TextStyle(color: palette.textMuted, fontSize: 22)),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final String title;
  final double progress;
  final VoidCallback onToggleControls;

  const _TopBar({
    required this.title,
    required this.progress,
    required this.onToggleControls,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Column(
      children: [
        Padding(
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
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Pressable(
                onPressed: onToggleControls,
                child: Icon(
                  Icons.text_fields_rounded,
                  color: palette.textPrimary,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
        LinearProgressIndicator(
          value: progress,
          minHeight: 2,
          backgroundColor: palette.surfaceBorder,
        ),
      ],
    );
  }
}
