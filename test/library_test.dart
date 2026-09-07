import 'package:caesar/features/reader/logic/reader_document.dart';
import 'package:flutter_test/flutter_test.dart';

/// Written before the implementation.
void main() {
  final added = DateTime(2026, 4, 15);

  ReaderDocument doc({
    String id = 'a',
    String title = 'A Book',
    List<String>? paragraphs,
    int progress = 0,
  }) => ReaderDocument(
    id: id,
    title: title,
    paragraphs: paragraphs ?? const ['One.', 'Two.', 'Three.', 'Four.'],
    addedAt: added,
    progressParagraph: progress,
  );

  group('Document', () {
    test('reports progress as a fraction of paragraphs read', () {
      expect(doc().progress, 0);
      expect(doc(progress: 2).progress, 0.5);
      expect(doc(progress: 4).progress, 1);
    });

    test('an empty document is not divided by zero', () {
      final empty = doc(paragraphs: const []);
      expect(empty.progress, 0);
      expect(empty.isEmpty, isTrue);
    });

    test('knows when it has been finished', () {
      expect(doc(progress: 4).isFinished, isTrue);
      expect(doc(progress: 3).isFinished, isFalse);
    });

    test('survives a round trip through storage', () {
      final restored = ReaderDocument.fromJson(doc(progress: 2).toJson());
      expect(restored, isNotNull);
      expect(restored!.title, 'A Book');
      expect(restored.paragraphs.length, 4);
      expect(restored.progressParagraph, 2);
      expect(restored.addedAt, added);
    });

    test('rejects malformed stored data instead of throwing', () {
      expect(ReaderDocument.fromJson(null), isNull);
      expect(ReaderDocument.fromJson({'title': 'no id'}), isNull);
    });
  });

  group('Library', () {
    test('adds a document and keeps the newest first', () {
      final library = ReaderLibrary.empty()
          .add(doc(title: 'Older'))
          .add(
            ReaderDocument(
              id: 'b',
              title: 'Newer',
              paragraphs: const ['x'],
              addedAt: added.add(const Duration(days: 1)),
            ),
          );
      expect(library.documents.first.title, 'Newer');
      expect(library.documents.length, 2);
    });

    test('adding the same id twice replaces rather than duplicates', () {
      final library = ReaderLibrary.empty()
          .add(doc(title: 'First'))
          .add(doc(title: 'Second'));
      expect(library.documents.length, 1);
      expect(library.documents.single.title, 'Second');
    });

    test('records reading progress for one document only', () {
      final library = ReaderLibrary.empty()
          .add(doc())
          .add(doc(id: 'b'))
          .withProgress('a', 3);
      expect(library.byId('a')!.progressParagraph, 3);
      expect(library.byId('b')!.progressParagraph, 0);
    });

    test('removes a document', () {
      final library = ReaderLibrary.empty().add(doc()).remove('a');
      expect(library.documents, isEmpty);
    });

    test('survives a round trip through storage', () {
      final library = ReaderLibrary.empty().add(doc(progress: 1));
      final restored = ReaderLibrary.decode(library.encode());
      expect(restored.documents.single.title, 'A Book');
      expect(restored.documents.single.progressParagraph, 1);
    });

    test('decoding rubbish yields an empty library', () {
      expect(ReaderLibrary.decode('nonsense').documents, isEmpty);
      expect(ReaderLibrary.decode(null).documents, isEmpty);
    });
  });
}
