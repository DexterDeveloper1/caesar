/// Repairs raw text extracted from a document so it can be read comfortably.
///
/// Extraction gives you the text a PDF *contains*, not the text a person wants
/// to read: running headers appear on every page, sentences are chopped by hard
/// line breaks, words are split with hyphens, and page numbers sit in the middle
/// of prose. Reflowing without fixing those is why documents feel unreadable on
/// a phone. Everything here is pure so each repair is directly testable.
library;

/// Words an average adult reads per minute.
const int _wordsPerMinute = 200;

/// A line must appear on at least this share of pages to count as a running
/// header or footer.
const double _repeatThreshold = 0.6;

/// How many lines at each end of a page are candidates for header/footer.
const int _edgeLines = 2;

/// Cleans per-page raw text into reflowable paragraphs.
List<String> cleanDocument(List<String> pages) {
  if (pages.isEmpty) return const [];

  final stripped = _stripRepeatedEdges(pages);
  final paragraphs = <String>[];

  for (final page in stripped) {
    paragraphs.addAll(_pageToParagraphs(page));
  }
  return paragraphs.where((p) => p.trim().isNotEmpty).toList();
}

/// Whether the document carries a usable text layer.
///
/// A scanned book is a stack of images: pages exist but extraction returns
/// nothing, and the reader must say so rather than showing a blank page.
bool hasExtractableText(List<String> pages) {
  final words = pages
      .join(' ')
      .split(RegExp(r'\s+'))
      .where((w) => w.trim().isNotEmpty)
      .length;
  return words >= 5;
}

/// Rough reading time in minutes, rounded up to at least one.
int estimateReadingMinutes(List<String> pages) {
  final words = pages
      .join(' ')
      .split(RegExp(r'\s+'))
      .where((w) => w.trim().isNotEmpty)
      .length;
  if (words == 0) return 0;
  final minutes = (words / _wordsPerMinute).ceil();
  return minutes < 1 ? 1 : minutes;
}

/// Removes lines that recur at the top or bottom of most pages, plus anything
/// that is obviously pagination.
List<String> _stripRepeatedEdges(List<String> pages) {
  final counts = <String, int>{};
  for (final page in pages) {
    final lines = _lines(page);
    final edges = <String>{
      ...lines.take(_edgeLines),
      ...lines.reversed.take(_edgeLines),
    };
    for (final line in edges) {
      counts[line] = (counts[line] ?? 0) + 1;
    }
  }

  final minimum = (pages.length * _repeatThreshold).ceil();
  final repeated = {
    for (final entry in counts.entries)
      // A single-page document has nothing to compare against.
      if (pages.length > 1 && entry.value >= minimum) entry.key,
  };

  return [
    for (final page in pages)
      // Blank lines are kept: they are the document's own paragraph breaks,
      // and dropping them here would merge paragraphs downstream.
      page
          .split('\n')
          .where((raw) {
            final line = raw.trim();
            if (line.isEmpty) return true;
            return !repeated.contains(line) && !_isPagination(line);
          })
          .join('\n'),
  ];
}

List<String> _lines(String page) =>
    page.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

/// Bare page numbers and "Page 4 of 200" style markers.
bool _isPagination(String line) {
  final trimmed = line.trim();
  if (RegExp(r'^[ivxlcdm]+$', caseSensitive: false).hasMatch(trimmed) &&
      trimmed.length <= 6) {
    return true;
  }
  if (RegExp(r'^\d{1,4}$').hasMatch(trimmed)) return true;
  return RegExp(
    r'^page\s+\d+(\s+of\s+\d+)?$',
    caseSensitive: false,
  ).hasMatch(trimmed);
}

/// Turns one page of lines into paragraphs, repairing hyphens and hard wraps.
List<String> _pageToParagraphs(String page) {
  // A blank line is an explicit paragraph break, so split on those first.
  final blocks = page.split(RegExp(r'\n\s*\n'));
  final paragraphs = <String>[];

  for (final block in blocks) {
    final lines = _lines(block);
    if (lines.isEmpty) continue;

    // A "short" line is one well under the typical width, which usually means
    // the paragraph ended rather than wrapped.
    final widths = lines.map((l) => l.length).toList()..sort();
    final median = widths[widths.length ~/ 2];
    final shortEnough = median * 0.75;

    final buffer = StringBuffer();
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final isLast = i == lines.length - 1;

      if (line.endsWith('-') && !isLast) {
        final next = lines[i + 1];
        // Keep the hyphen when the continuation is a proper noun — "Anglo-
        // Saxon" is hyphenated, not a split word.
        final joinsWord = next.isNotEmpty && next[0] == next[0].toLowerCase();
        buffer.write(joinsWord ? line.substring(0, line.length - 1) : line);
        continue;
      }

      buffer.write(line);

      final endsSentence = RegExp(r'[.!?]["\u201d\u2019)]?$').hasMatch(line);
      final looksFinal = line.length < shortEnough && endsSentence;

      if (isLast || looksFinal) {
        paragraphs.add(_normalise(buffer.toString()));
        buffer.clear();
      } else {
        buffer.write(' ');
      }
    }
    if (buffer.isNotEmpty) paragraphs.add(_normalise(buffer.toString()));
  }
  return paragraphs.where((p) => p.isNotEmpty).toList();
}

String _normalise(String text) => text.replaceAll(RegExp(r'\s+'), ' ').trim();
