import 'dart:io';

import 'package:caesar/features/reader/logic/document_cleaner.dart';
import 'package:caesar/features/reader/logic/reader_document.dart';
import 'package:epubx/epubx.dart' as epub;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as pdf;

/// Why an import failed, in terms a reader will understand.
enum ImportFailure { unsupported, unreadable, noTextLayer }

class ImportException implements Exception {
  final ImportFailure reason;

  const ImportException(this.reason);

  String get message => switch (reason) {
    ImportFailure.unsupported =>
      'That file type is not supported yet. Try a PDF, EPUB or TXT file.',
    ImportFailure.unreadable =>
      'That file could not be opened. It may be damaged or '
          'password-protected.',
    ImportFailure.noTextLayer =>
      'This document is a scan — the pages are images with no text in them, '
          'so there is nothing to reflow yet.',
  };
}

/// Turns a file on disk into a cleaned, reflowable document.
class DocumentImporter {
  const DocumentImporter();

  static const Set<String> supportedExtensions = {'pdf', 'epub', 'txt'};

  Future<ReaderDocument> import(File file) async {
    final name = file.path.split(RegExp(r'[/\\]')).last;
    final extension = name.contains('.')
        ? name.split('.').last.toLowerCase()
        : '';

    if (!supportedExtensions.contains(extension)) {
      throw const ImportException(ImportFailure.unsupported);
    }

    final List<String> rawPages;
    try {
      rawPages = switch (extension) {
        'pdf' => await _extractPdf(file),
        'epub' => await _extractEpub(file),
        _ => [await file.readAsString()],
      };
    } on ImportException {
      rethrow;
    } catch (error) {
      debugPrint('Import failed: $error');
      throw const ImportException(ImportFailure.unreadable);
    }

    // A scanned book yields pages with no text at all — say so rather than
    // opening an empty reader.
    if (!hasExtractableText(rawPages)) {
      throw const ImportException(ImportFailure.noTextLayer);
    }

    final paragraphs = cleanDocument(rawPages);
    if (paragraphs.isEmpty) {
      throw const ImportException(ImportFailure.noTextLayer);
    }

    return ReaderDocument(
      id: '${file.path}:${await file.length()}',
      title: _titleFrom(name),
      paragraphs: paragraphs,
      addedAt: DateTime.now(),
    );
  }

  /// Extracts text page by page, so the cleaner can spot per-page artifacts
  /// like running headers.
  Future<List<String>> _extractPdf(File file) async {
    final document = pdf.PdfDocument(inputBytes: await file.readAsBytes());
    try {
      final extractor = pdf.PdfTextExtractor(document);
      return [
        for (var page = 0; page < document.pages.count; page++)
          extractor.extractText(startPageIndex: page, endPageIndex: page),
      ];
    } finally {
      document.dispose();
    }
  }

  /// EPUB is structured HTML, so extraction is far more reliable than PDF —
  /// each chapter becomes a "page" for the cleaner.
  Future<List<String>> _extractEpub(File file) async {
    final book = await epub.EpubReader.readBook(await file.readAsBytes());
    final chapters = <String>[];

    void walk(List<epub.EpubChapter>? list) {
      for (final chapter in list ?? const <epub.EpubChapter>[]) {
        final html = chapter.HtmlContent;
        if (html != null && html.isNotEmpty) chapters.add(_stripHtml(html));
        walk(chapter.SubChapters);
      }
    }

    walk(book.Chapters);
    if (chapters.isEmpty) {
      // Some EPUBs have no chapter tree; fall back to the raw content files.
      final content = book.Content?.Html?.values;
      for (final epub.EpubTextContentFile item
          in content ?? const <epub.EpubTextContentFile>[]) {
        final html = item.Content;
        if (html != null && html.isNotEmpty) chapters.add(_stripHtml(html));
      }
    }
    return chapters;
  }

  /// Converts chapter HTML to plain text, keeping block boundaries as the
  /// blank lines the cleaner reads as paragraph breaks.
  String _stripHtml(String html) {
    var text = html
        .replaceAll(RegExp(r'<(script|style)[^>]*>.*?</\1>', dotAll: true), ' ')
        .replaceAllMapped(
          RegExp(r'</(p|div|h[1-6]|li|blockquote)>', caseSensitive: false),
          (_) => '\n\n',
        )
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), ' ');

    // Decode the handful of entities that actually appear in book text.
    const entities = {
      '&nbsp;': ' ',
      '&amp;': '&',
      '&lt;': '<',
      '&gt;': '>',
      '&quot;': '"',
      '&#39;': "'",
      '&rsquo;': '’',
      '&lsquo;': '‘',
      '&ldquo;': '“',
      '&rdquo;': '”',
      '&mdash;': '—',
      '&ndash;': '–',
    };
    entities.forEach((from, to) => text = text.replaceAll(from, to));
    return text;
  }

  String _titleFrom(String fileName) {
    final withoutExtension = fileName.contains('.')
        ? fileName.substring(0, fileName.lastIndexOf('.'))
        : fileName;
    final spaced = withoutExtension.replaceAll(RegExp(r'[_-]+'), ' ').trim();
    return spaced.isEmpty ? 'Untitled' : spaced;
  }
}

final documentImporterProvider = Provider<DocumentImporter>(
  (ref) => const DocumentImporter(),
);
