import 'dart:convert';

import 'package:caesar/core/training_mode.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// One row of the global leaderboard.
@immutable
class LeaderboardEntry {
  final int rank;
  final String displayName;
  final int score;
  final bool isYou;

  const LeaderboardEntry({
    required this.rank,
    required this.displayName,
    required this.score,
    required this.isYou,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      rank: json['rank'] as int? ?? 0,
      displayName: json['displayName'] as String? ?? 'Anonymous',
      score: json['score'] as int? ?? 0,
      isYou: json['isYou'] as bool? ?? false,
    );
  }
}

/// Result of submitting a score to the server.
@immutable
class SubmitResult {
  final int best;
  final bool improved;
  final int rank;

  const SubmitResult({
    required this.best,
    required this.improved,
    required this.rank,
  });

  factory SubmitResult.fromJson(Map<String, dynamic> json) {
    return SubmitResult(
      best: json['best'] as int? ?? 0,
      improved: json['improved'] as bool? ?? false,
      rank: json['rank'] as int? ?? 0,
    );
  }
}

/// Raised when the API cannot be reached or returns an error. Callers are
/// expected to degrade gracefully — the app is offline-first.
class LeaderboardException implements Exception {
  final String message;

  const LeaderboardException(this.message);

  @override
  String toString() => 'LeaderboardException: $message';
}

/// Thin client for the Caesar API (`server/`).
class LeaderboardApi {
  final String baseUrl;
  final http.Client _client;
  final Duration timeout;

  LeaderboardApi({
    required this.baseUrl,
    http.Client? client,
    this.timeout = const Duration(seconds: 6),
  }) : _client = client ?? http.Client();

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('$baseUrl$path').replace(queryParameters: query);

  Future<SubmitResult> submitScore({
    required String deviceId,
    required TrainingMode mode,
    required int score,
    String? displayName,
  }) async {
    try {
      final response = await _client
          .post(
            _uri('/v1/scores'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'deviceId': deviceId,
              'mode': mode.name,
              'score': score,
              if (displayName != null && displayName.trim().isNotEmpty)
                'displayName': displayName.trim(),
            }),
          )
          .timeout(timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw LeaderboardException('Submit failed (${response.statusCode})');
      }
      return SubmitResult.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    } on LeaderboardException {
      rethrow;
    } catch (e) {
      throw LeaderboardException('$e');
    }
  }

  Future<List<LeaderboardEntry>> leaderboard({
    required TrainingMode mode,
    String? deviceId,
    int limit = 50,
  }) async {
    try {
      final response = await _client
          .get(
            _uri('/v1/leaderboard/${mode.name}', {
              'limit': '$limit',
              if (deviceId != null) 'deviceId': deviceId,
            }),
          )
          .timeout(timeout);

      if (response.statusCode != 200) {
        throw LeaderboardException('Fetch failed (${response.statusCode})');
      }
      final list = jsonDecode(response.body) as List<dynamic>;
      return list
          .map((e) => LeaderboardEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } on LeaderboardException {
      rethrow;
    } catch (e) {
      throw LeaderboardException('$e');
    }
  }

  void dispose() => _client.close();
}
