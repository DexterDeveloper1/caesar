import 'package:caesar/features/vocabulary/data/definition_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Written before the implementation. The parser is pure so the response
/// handling is testable without any network.
void main() {
  group('Parsing a dictionary response', () {
    const body = '''
[
  {
    "word": "mountain",
    "meanings": [
      {
        "partOfSpeech": "noun",
        "definitions": [
          {"definition": "A large natural elevation of the earth's surface."},
          {"definition": "A large heap."}
        ]
      }
    ]
  }
]
''';

    test('takes the first definition and its part of speech', () {
      final result = parseDefinition(body);
      expect(
        result,
        "noun · A large natural elevation of the earth's surface.",
      );
    });

    test('returns null when the word has no entry', () {
      expect(parseDefinition('{"title":"No Definitions Found"}'), isNull);
    });

    test('returns null for malformed json rather than throwing', () {
      expect(parseDefinition('not json at all'), isNull);
      expect(parseDefinition(''), isNull);
    });

    test('survives entries missing the fields it wants', () {
      expect(parseDefinition('[{"word":"x"}]'), isNull);
      expect(parseDefinition('[{"meanings":[]}]'), isNull);
      expect(parseDefinition('[{"meanings":[{"definitions":[]}]}]'), isNull);
    });

    test('copes with a missing part of speech', () {
      const noPos =
          '[{"meanings":[{"definitions":[{"definition":"A thing."}]}]}]';
      expect(parseDefinition(noPos), 'A thing.');
    });
  });
}
