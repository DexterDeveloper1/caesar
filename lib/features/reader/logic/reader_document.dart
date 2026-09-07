import 'dart:convert';

import 'package:flutter/foundation.dart';

/// An imported document, already cleaned into reflowable paragraphs.
///
/// Paragraphs are stored rather than the original file: the whole point of the
/// reader is that the cleaned text is what you read, and keeping it means a
/// document is imported (and repaired) exactly once.
@immutable
class ReaderDocument {
  final String id;
  final String title;
  final List<String> paragraphs;
  final DateTime addedAt;

  /// Index of the first paragraph not yet read.
  final int progressParagraph;

  /// Indices of paragraphs that are headings, so the reader can style them.
  final Set<int> headingIndices;

  /// Exact scroll position when reading stopped.
  ///
  /// Paragraph index alone cannot restore the view: in a lazily-built list an
  /// off-screen paragraph has no context to scroll to, which is why resuming
  /// silently fell back to the top.
  final double scrollOffset;

  const ReaderDocument({
    required this.id,
    required this.title,
    required this.paragraphs,
    required this.addedAt,
    this.progressParagraph = 0,
    this.headingIndices = const {},
    this.scrollOffset = 0,
  });

  bool get isEmpty => paragraphs.isEmpty;

  double get progress => paragraphs.isEmpty
      ? 0
      : (progressParagraph / paragraphs.length).clamp(0, 1);

  bool get isFinished =>
      paragraphs.isNotEmpty && progressParagraph >= paragraphs.length;

  bool isHeading(int index) => headingIndices.contains(index);

  ReaderDocument copyWith({int? progressParagraph, double? scrollOffset}) =>
      ReaderDocument(
        id: id,
        title: title,
        paragraphs: paragraphs,
        addedAt: addedAt,
        progressParagraph: progressParagraph ?? this.progressParagraph,
        headingIndices: headingIndices,
        scrollOffset: scrollOffset ?? this.scrollOffset,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'paragraphs': paragraphs,
    'addedAt': addedAt.toIso8601String(),
    'progress': progressParagraph,
    'headings': headingIndices.toList(),
    'offset': scrollOffset,
  };

  static ReaderDocument? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final title = json['title'];
    final addedAt = DateTime.tryParse('${json['addedAt']}');
    if (id is! String || title is! String || addedAt == null) return null;

    final raw = json['paragraphs'];
    final paragraphs = raw is List
        ? raw.whereType<String>().toList(growable: false)
        : const <String>[];
    final progress = json['progress'];
    final headings = json['headings'];
    final offset = json['offset'];

    return ReaderDocument(
      id: id,
      title: title,
      paragraphs: paragraphs,
      addedAt: addedAt,
      progressParagraph: progress is int ? progress : 0,
      headingIndices: headings is List
          ? headings.whereType<int>().toSet()
          : const {},
      scrollOffset: offset is num ? offset.toDouble() : 0,
    );
  }
}

/// The player's imported documents, newest first.
@immutable
class ReaderLibrary {
  final List<ReaderDocument> documents;

  const ReaderLibrary(this.documents);

  factory ReaderLibrary.empty() => const ReaderLibrary([]);

  ReaderDocument? byId(String id) {
    for (final doc in documents) {
      if (doc.id == id) return doc;
    }
    return null;
  }

  ReaderLibrary add(ReaderDocument document) {
    // Re-importing the same file updates it rather than duplicating.
    final rest = documents.where((d) => d.id != document.id);
    return ReaderLibrary(
      [document, ...rest]..sort((a, b) => b.addedAt.compareTo(a.addedAt)),
    );
  }

  ReaderLibrary remove(String id) =>
      ReaderLibrary(documents.where((d) => d.id != id).toList());

  ReaderLibrary withProgress(String id, int paragraph, {double? offset}) =>
      ReaderLibrary([
        for (final doc in documents)
          if (doc.id == id)
            doc.copyWith(progressParagraph: paragraph, scrollOffset: offset)
          else
            doc,
      ]);

  String encode() => jsonEncode(documents.map((d) => d.toJson()).toList());

  static ReaderLibrary decode(String? raw) {
    if (raw == null || raw.isEmpty) return ReaderLibrary.empty();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return ReaderLibrary.empty();
      return ReaderLibrary([
        for (final entry in decoded)
          if (ReaderDocument.fromJson(entry) case final doc?) doc,
      ]);
    } on FormatException {
      return ReaderLibrary.empty();
    }
  }
}
