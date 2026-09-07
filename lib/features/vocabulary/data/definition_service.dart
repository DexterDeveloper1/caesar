import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

/// Looks up word meanings.
///
/// The game itself never needs the network — definitions are fetched only when
/// the player opens a saved word, and the result is then stored on the device,
/// so each word costs at most one request ever.
abstract class DefinitionService {
  /// Returns a short definition, or null if none could be found.
  Future<String?> lookup(String word);
}

/// Extracts a readable definition from a dictionaryapi.dev response.
///
/// Pure and defensive: the endpoint returns an object (not a list) when a word
/// is unknown, and entries can be missing any field.
String? parseDefinition(String body) {
  if (body.trim().isEmpty) return null;
  try {
    final decoded = jsonDecode(body);
    if (decoded is! List || decoded.isEmpty) return null;

    final first = decoded.first;
    if (first is! Map) return null;

    final meanings = first['meanings'];
    if (meanings is! List || meanings.isEmpty) return null;

    final meaning = meanings.first;
    if (meaning is! Map) return null;

    final definitions = meaning['definitions'];
    if (definitions is! List || definitions.isEmpty) return null;

    final entry = definitions.first;
    if (entry is! Map) return null;

    final text = entry['definition'];
    if (text is! String || text.isEmpty) return null;

    final partOfSpeech = meaning['partOfSpeech'];
    return partOfSpeech is String && partOfSpeech.isNotEmpty
        ? '$partOfSpeech · $text'
        : text;
  } on FormatException {
    return null;
  }
}

/// Fetches definitions from the free dictionaryapi.dev endpoint.
class HttpDefinitionService implements DefinitionService {
  final http.Client _client;

  HttpDefinitionService({http.Client? client})
    : _client = client ?? http.Client();

  static const String _base = 'https://api.dictionaryapi.dev/api/v2/entries/en';

  @override
  Future<String?> lookup(String word) async {
    try {
      final response = await _client
          .get(Uri.parse('$_base/$word'))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      return parseDefinition(response.body);
    } catch (_) {
      // Offline, blocked, or slow — the screen simply says it couldn't fetch.
      return null;
    }
  }
}

final definitionServiceProvider = Provider<DefinitionService>(
  (ref) => HttpDefinitionService(),
);
