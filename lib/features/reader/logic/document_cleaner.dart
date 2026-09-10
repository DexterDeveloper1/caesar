/// Repairs raw text extracted from a document so it can be read comfortably.
///
/// Extraction gives you the text a PDF *contains*, not the text a person wants
/// to read. Worse, extractors disagree wildly about line structure — measured
/// across five real books, one returned whole paragraphs as single 1000+
/// character lines, another returned a single word per line with a blank line
/// between each, and a third returned tab-separated words. A cleaner tuned for
/// one shape produces gibberish on the others, so the shape is detected per
/// page and repaired accordingly.
library;

/// Words an average adult reads per minute.
const int _wordsPerMinute = 200;

/// A line must appear on at least this share of pages to count as boilerplate.
const double _repeatThreshold = 0.6;

/// Boilerplate is always short; body text is not.
const int _maxBoilerplateLength = 80;

/// Longest a paragraph may be before it is split at a sentence boundary.
///
/// Real pages produced blocks of nearly 3,000 characters — an unreadable wall
/// on a phone.
const int _maxParagraphLength = 700;

/// Below this average line length the extractor has exploded the page into
/// individual words.
const int _explodedLineLength = 15;

/// Above this, it has glued whole paragraphs (or pages) onto single lines.
const int _gluedLineLength = 150;

/// Longest a line can be and still plausibly be a heading.
const int _maxHeadingLength = 60;

/// A paragraph of the cleaned document, tagged so headings can be styled.
class DocumentBlock {
  final String text;
  final bool isHeading;

  const DocumentBlock(this.text, {this.isHeading = false});
}

/// Whether a line looks like a heading rather than prose.
///
/// Extraction carries no styling, so headings have to be inferred. Without
/// this, "ACKNOWLEDGMENTS" is joined onto the sentence that follows it.
bool looksLikeHeading(String line) {
  final trimmed = line.trim();
  if (trimmed.isEmpty || trimmed.length > _maxHeadingLength) return false;
  // Prose ends in punctuation; headings almost never do.
  if (RegExp(r'[.,;:]$').hasMatch(trimmed)) return false;

  // Standalone front/back-matter headings.
  if (RegExp(
    r'^(prologue|epilogue|preface|foreword|introduction|contents|afterword|'
    r'acknowledge?ments?|appendix|dedication|epigraph)[.:]?$',
    caseSensitive: false,
  ).hasMatch(trimmed)) {
    return true;
  }

  // "Chapter 12", "Part Two", "Book IV".
  if (RegExp(
    r'^(chapter|part|book|section)\s*'
    r'(\d+|[ivxlcdm]+|one|two|three|four|five|six|seven|eight|nine|ten|'
    r'eleven|twelve|thirteen|fourteen|fifteen|sixteen|seventeen|eighteen|'
    r'nineteen|twenty)?[.:]?$',
    caseSensitive: false,
  ).hasMatch(trimmed)) {
    return true;
  }

  // A short line in capitals, e.g. "ACKNOWLEDGMENTS".
  final letters = trimmed.replaceAll(RegExp(r'[^A-Za-z]'), '');
  if (letters.length >= 3 && letters == letters.toUpperCase()) return true;

  return false;
}

/// Cleans per-page raw text into paragraphs, tagging headings.
List<DocumentBlock> cleanDocumentBlocks(List<String> pages) => [
  for (final text in cleanDocument(pages))
    DocumentBlock(text, isHeading: looksLikeHeading(text)),
];

/// Cleans per-page raw text into reflowable paragraphs.
List<String> cleanDocument(List<String> pages) {
  if (pages.isEmpty) return const [];

  final stripped = _stripBoilerplate(pages);
  final paragraphs = <String>[];
  for (final page in stripped) {
    paragraphs.addAll(_pageToParagraphs(page));
  }

  // Finally, break any remaining wall of text at sentence boundaries.
  return [
    for (final paragraph in paragraphs)
      if (paragraph.trim().isNotEmpty) ..._splitLongParagraph(paragraph.trim()),
  ];
}

/// Whether the document carries a usable text layer.
///
/// A scanned book is a stack of images: pages exist but extraction returns
/// nothing, and the reader must say so rather than showing a blank page.
bool hasExtractableText(List<String> pages) => _wordCount(pages) >= 5;

/// Rough reading time in minutes, rounded up to at least one.
int estimateReadingMinutes(List<String> pages) {
  final words = _wordCount(pages);
  if (words == 0) return 0;
  final minutes = (words / _wordsPerMinute).ceil();
  return minutes < 1 ? 1 : minutes;
}

int _wordCount(List<String> pages) => pages
    .join(' ')
    .split(RegExp(r'\s+'))
    .where((w) => w.trim().isNotEmpty)
    .length;

// ---------------------------------------------------------------- boilerplate

/// Removes lines that recur across pages, plus pagination.
///
/// Unlike a naive header/footer strip this scans the whole page: real books put
/// promotional lines and watermarks in the middle of the text too. Repetition
/// across most pages is what identifies boilerplate, so body text is safe.
List<String> _stripBoilerplate(List<String> pages) {
  if (pages.length < 2) {
    return [for (final page in pages) _removePagination(page)];
  }

  final counts = <String, int>{};
  for (final page in pages) {
    // Count each distinct line once per page.
    for (final line in _contentLines(page).map(_boilerplateKey).toSet()) {
      counts[line] = (counts[line] ?? 0) + 1;
    }
  }

  final minimum = (pages.length * _repeatThreshold).ceil();
  final repeated = {
    for (final entry in counts.entries)
      if (entry.value >= minimum && entry.key.length <= _maxBoilerplateLength)
        entry.key,
  };

  return [
    for (final page in pages)
      // Blank lines survive: they are the document's own paragraph breaks.
      page
          .split('\n')
          .where((raw) {
            final line = raw.trim();
            if (line.isEmpty) return true;
            if (_isPagination(line)) return false;
            // Never discard a heading, even a repeated one.
            if (looksLikeHeading(line)) return true;
            return !repeated.contains(_boilerplateKey(line));
          })
          .join('\n'),
  ];
}

/// Normalises a line for repeat-detection.
///
/// Running headers often carry the page number glued on — "The Five Laws of
/// Gold69", "…Gold70" — so trailing digits are dropped before comparing.
String _boilerplateKey(String line) =>
    line.trim().replaceAll(RegExp(r'\s*\d+\s*$'), '').trim();

String _removePagination(String page) => page
    .split('\n')
    .where((raw) => raw.trim().isEmpty || !_isPagination(raw.trim()))
    .join('\n');

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

List<String> _contentLines(String page) =>
    page.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

// ------------------------------------------------------------------- shaping

enum _LineShape { exploded, wrapped, glued }

/// Classifies how the extractor laid this page out.
_LineShape _shapeOf(List<String> lines) {
  if (lines.isEmpty) return _LineShape.wrapped;
  final total = lines.fold<int>(0, (sum, l) => sum + l.length);
  final average = total / lines.length;
  if (average < _explodedLineLength) return _LineShape.exploded;
  if (average > _gluedLineLength) return _LineShape.glued;
  return _LineShape.wrapped;
}

List<String> _pageToParagraphs(String page) {
  final lines = _contentLines(page);
  if (lines.isEmpty) return const [];

  switch (_shapeOf(lines)) {
    case _LineShape.exploded:
      // One word per line: blank lines are noise, not paragraph breaks.
      return [_joinLines(lines)];
    case _LineShape.glued:
      // Each line already holds whole paragraphs; splitting happens later.
      return [for (final line in lines) _normalise(line)];
    case _LineShape.wrapped:
      return _wrappedToParagraphs(page);
  }
}

/// Joins word-per-line output back into running text, repairing hyphens.
String _joinLines(List<String> lines) {
  final buffer = StringBuffer();
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final joinsWord =
        line.endsWith('-') &&
        i + 1 < lines.length &&
        lines[i + 1].isNotEmpty &&
        lines[i + 1][0] == lines[i + 1][0].toLowerCase();
    if (joinsWord) {
      buffer.write(line.substring(0, line.length - 1));
      continue;
    }
    buffer.write(line);
    if (i != lines.length - 1) buffer.write(' ');
  }
  return _normalise(buffer.toString());
}

/// The classic case: hard-wrapped lines that must be rejoined into paragraphs.
List<String> _wrappedToParagraphs(String page) {
  final blocks = page.split(RegExp(r'\n\s*\n'));
  final paragraphs = <String>[];

  for (final block in blocks) {
    final lines = _contentLines(block);
    if (lines.isEmpty) continue;

    // A "short" line is well under the typical width, which usually means the
    // paragraph ended rather than wrapped.
    final widths = lines.map((l) => l.length).toList()..sort();
    final median = widths[widths.length ~/ 2];
    final shortEnough = median * 0.75;

    final buffer = StringBuffer();
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final isLast = i == lines.length - 1;

      if (line.endsWith('-') && !isLast) {
        final next = lines[i + 1];
        // Keep the hyphen when the continuation is a proper noun: "Anglo-
        // Saxon" is hyphenated, not a split word.
        final joinsWord = next.isNotEmpty && next[0] == next[0].toLowerCase();
        buffer.write(joinsWord ? line.substring(0, line.length - 1) : line);
        continue;
      }

      // A heading stands alone, so flush it rather than letting the sentence
      // that follows run onto it.
      if (looksLikeHeading(line)) {
        if (buffer.isNotEmpty) {
          paragraphs.add(_normalise(buffer.toString()));
          buffer.clear();
        }
        paragraphs.add(_normalise(line));
        continue;
      }

      buffer.write(line);

      final endsSentence = RegExp(r'[.!?]["”’)]?$').hasMatch(line);
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

// ------------------------------------------------------------------ splitting

/// Breaks an over-long paragraph at sentence boundaries.
///
/// Never drops text: the pieces concatenated are the original words.
List<String> _splitLongParagraph(String paragraph) {
  if (paragraph.length <= _maxParagraphLength) return [paragraph];
  if (looksLikeHeading(paragraph)) return [paragraph];

  final sentences = _splitIntoSentences(paragraph);
  if (sentences.length < 2) return [paragraph];

  final packed = <String>[];
  final buffer = StringBuffer();
  for (final sentence in sentences) {
    if (buffer.isNotEmpty &&
        buffer.length + 1 + sentence.length > _maxParagraphLength) {
      packed.add(buffer.toString().trim());
      buffer.clear();
    }
    if (buffer.isNotEmpty) buffer.write(' ');
    buffer.write(sentence);
  }
  if (buffer.isNotEmpty) packed.add(buffer.toString().trim());
  return packed;
}

/// Splits on sentence-ending punctuation followed by a capitalised word.
List<String> _splitIntoSentences(String text) {
  const closers = '"”’\')]';
  final sentences = <String>[];
  var start = 0;

  for (var i = 0; i < text.length; i++) {
    final char = text[i];
    if (char != '.' && char != '!' && char != '?') continue;

    var end = i + 1;
    while (end < text.length && closers.contains(text[end])) {
      end++;
    }
    if (end >= text.length) break;
    if (text[end] != ' ' && text[end] != '\t' && text[end] != '\n') continue;

    var next = end;
    while (next < text.length &&
        (text[next] == ' ' || text[next] == '\t' || text[next] == '\n')) {
      next++;
    }
    if (next >= text.length) break;

    // Only break before something that starts a sentence.
    final following = text[next];
    final isUpper =
        following.toUpperCase() == following &&
        following.toLowerCase() != following;
    if (!isUpper) continue;

    sentences.add(text.substring(start, end).trim());
    start = next;
    i = next - 1;
  }

  final rest = text.substring(start).trim();
  if (rest.isNotEmpty) sentences.add(rest);
  return sentences;
}

/// Collapses every run of whitespace — including the tabs one extractor used
/// between every single word — to a single space.
String _normalise(String text) => text.replaceAll(RegExp(r'\s+'), ' ').trim();
