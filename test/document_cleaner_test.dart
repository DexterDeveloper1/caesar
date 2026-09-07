import 'package:caesar/features/reader/logic/document_cleaner.dart';
import 'package:flutter_test/flutter_test.dart';

/// Written before the implementation.
///
/// This is the part that makes the reader worth building: raw text pulled out
/// of a PDF is full of artifacts — running headers, page numbers, hyphens split
/// across lines, and hard line breaks mid-sentence — and reading it on a phone
/// is miserable until those are repaired.
void main() {
  group('Running headers and footers', () {
    test('strips a header repeated on most pages', () {
      final pages = [
        'A History of Rome\nChapter one begins here\nand continues.',
        'A History of Rome\nMore text on the second page.',
        'A History of Rome\nAnd the third page too.',
      ];
      final text = cleanDocument(pages).join('\n\n');
      expect(text, isNot(contains('A History of Rome')));
      expect(text, contains('Chapter one begins here'));
    });

    test('keeps a line that only appears once', () {
      final pages = [
        'A unique heading\nSome body text here.',
        'Different text entirely on page two.',
        'And more different text on page three.',
      ];
      final text = cleanDocument(pages).join('\n\n');
      expect(text, contains('A unique heading'));
    });

    test('strips bare page numbers', () {
      final pages = ['Body text of the book.\n12', 'More body text here.\n13'];
      final paragraphs = cleanDocument(pages);
      expect(paragraphs.join(' '), isNot(contains('12')));
      expect(paragraphs.join(' '), contains('Body text'));
    });

    test('strips "Page 4 of 200" style footers', () {
      final pages = [
        'Real content one.\nPage 4 of 200',
        'Real content two.\nPage 5 of 200',
      ];
      final text = cleanDocument(pages).join(' ');
      expect(text, isNot(contains('Page')));
    });
  });

  group('Hyphenation', () {
    test('rejoins a word split across lines', () {
      final result = cleanDocument(['He could not under-\nstand the rule.']);
      expect(result.single, 'He could not understand the rule.');
    });

    test('keeps a genuine hyphen inside a line', () {
      final result = cleanDocument(['A well-known problem persists.']);
      expect(result.single, contains('well-known'));
    });

    test('does not merge when the next line starts a proper noun', () {
      // "Anglo-" + "Saxon" should stay hyphenated, not become "AngloSaxon".
      final result = cleanDocument(['They studied Anglo-\nSaxon poetry.']);
      expect(result.single, contains('Anglo-Saxon'));
    });
  });

  group('Paragraph reconstruction', () {
    test('joins hard-wrapped lines into one paragraph', () {
      final result = cleanDocument([
        'This sentence was wrapped\nacross three separate\nlines by the PDF.',
      ]);
      expect(
        result.single,
        'This sentence was wrapped across three separate lines by the PDF.',
      );
    });

    test('a blank line starts a new paragraph', () {
      final result = cleanDocument([
        'First paragraph text.\n\nSecond paragraph text.',
      ]);
      expect(result.length, 2);
      expect(result.first, 'First paragraph text.');
      expect(result.last, 'Second paragraph text.');
    });

    test('a short line ending a sentence ends the paragraph', () {
      final result = cleanDocument([
        'A long line of running text that clearly continues onward and on\n'
            'and finally stops.\n'
            'A brand new paragraph starts on this line and runs along nicely.',
      ]);
      expect(result.length, greaterThan(1));
    });
  });

  group('Whitespace and robustness', () {
    test('collapses runs of spaces and stray blank lines', () {
      final result = cleanDocument(['Too    many     spaces   here.']);
      expect(result.single, 'Too many spaces here.');
    });

    test('empty input yields no paragraphs', () {
      expect(cleanDocument([]), isEmpty);
      expect(cleanDocument(['', '   ', '\n\n']), isEmpty);
    });

    test('detects a document with no extractable text', () {
      // A scanned PDF: pages exist but carry no text layer.
      expect(hasExtractableText(['', '  ', '\n']), isFalse);
      expect(hasExtractableText(['Real sentences of prose here.']), isTrue);
    });
  });

  group('Reading estimates', () {
    test('estimates reading time from word count', () {
      final words = List.filled(400, 'word').join(' ');
      // ~200 wpm, so 400 words is about two minutes.
      expect(estimateReadingMinutes([words]), 2);
    });

    test('never reports zero minutes for real content', () {
      expect(estimateReadingMinutes(['a few words']), greaterThanOrEqualTo(1));
    });
  });

  group('Headings', () {
    test('an all-caps line is a heading, not part of the next sentence', () {
      // Real case from Angels & Demons: "ACKNOWLEDGMENTS" ran straight into
      // "A debt of gratitude..." as one sentence.
      final blocks = cleanDocumentBlocks([
        'ACKNOWLEDGMENTS\nA debt of gratitude to my friends and editors.',
      ]);
      expect(blocks.first.isHeading, isTrue);
      expect(blocks.first.text, 'ACKNOWLEDGMENTS');
      expect(blocks[1].isHeading, isFalse);
      expect(blocks[1].text, startsWith('A debt of gratitude'));
    });

    test('chapter markers are headings', () {
      for (final line in ['CHAPTER 1', 'Chapter 12', 'PROLOGUE', 'Part Two']) {
        final blocks = cleanDocumentBlocks([
          '$line\nThe story continues here.',
        ]);
        expect(blocks.first.isHeading, isTrue, reason: line);
        expect(blocks.first.text, line);
      }
    });

    test('a long all-caps passage is not treated as a heading', () {
      const shouting =
          'THIS IS A VERY LONG LINE OF SHOUTING THAT GOES ON AND ON AND IS '
          'CLEARLY NOT A HEADING BECAUSE IT IS FAR TOO LONG TO BE ONE AT ALL.';
      final blocks = cleanDocumentBlocks([shouting]);
      expect(blocks.single.isHeading, isFalse);
    });

    test('ordinary prose is never a heading', () {
      final blocks = cleanDocumentBlocks([
        'The camerlegno walked slowly down the corridor of the basilica.',
      ]);
      expect(blocks.single.isHeading, isFalse);
    });

    test('plain cleanDocument still returns text only', () {
      final text = cleanDocument(['ACKNOWLEDGMENTS\nA debt of gratitude.']);
      expect(text, ['ACKNOWLEDGMENTS', 'A debt of gratitude.']);
    });
  });
}
