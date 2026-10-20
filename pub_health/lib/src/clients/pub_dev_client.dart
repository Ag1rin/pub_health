import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/pub_dev_package_info.dart';
import 'pub_dev_cache.dart';

/// Client for the public pub.dev API.
class PubDevClient {
  /// Creates a pub.dev client.
  PubDevClient({
    http.Client? httpClient,
    PubDevCache? cache,
    this.baseUrl = 'https://pub.dev',
    this.timeout = const Duration(seconds: 20),
    this.maxRetries = 3,
  })  : _httpClient = httpClient ?? http.Client(),
        _cache = cache ?? PubDevCache(),
        _ownsClient = httpClient == null;

  /// API base URL (overridable for tests).
  final String baseUrl;

  /// Per-request timeout.
  final Duration timeout;

  /// Max retry attempts for 429 / 5xx.
  final int maxRetries;

  final http.Client _httpClient;
  final PubDevCache _cache;
  final bool _ownsClient;

  /// Fetches package metadata and score, using the in-memory cache.
  Future<PubDevPackageInfo> fetchPackage(String name) async {
    final cached = _cache.getPackage(name);
    if (cached != null) return cached;

    final packageJson = await _getJson('/api/packages/$name');
    PubDevScoreInfo? score;
    try {
      final scoreJson = await _getJson('/api/packages/$name/score');
      score = PubDevScoreInfo.fromJson(scoreJson);
      _cache.putScore(name, score);
    } on PubDevClientException catch (e) {
      if (!e.isNotFound) rethrow;
    }

    final info = PubDevPackageInfo.fromPackageJson(packageJson, score: score);
    _cache.putPackage(name, info);
    return info;
  }

  /// Closes the underlying HTTP client when owned by this instance.
  void close() {
    if (_ownsClient) {
      _httpClient.close();
    }
  }

  Future<Map<String, dynamic>> _getJson(String path) async {
    final uri = Uri.parse('$baseUrl$path');
    var attempt = 0;
    while (true) {
      attempt++;
      try {
        final response = await _httpClient.get(
          uri,
          headers: const {
            'Accept': 'application/json',
            'User-Agent': 'pub_health/0.1.0',
          },
        ).timeout(timeout);

        if (response.statusCode == 404) {
          throw PubDevClientException(
            'Package not found at $uri',
            statusCode: 404,
          );
        }

        if (response.statusCode == 429 || response.statusCode >= 500) {
          if (attempt <= maxRetries) {
            final delay = Duration(milliseconds: 200 * (1 << (attempt - 1)));
            await Future<void>.delayed(delay);
            continue;
          }
          throw PubDevClientException(
            'pub.dev returned ${response.statusCode} for $uri',
            statusCode: response.statusCode,
          );
        }

        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw PubDevClientException(
            'pub.dev returned ${response.statusCode} for $uri',
            statusCode: response.statusCode,
          );
        }

        final decoded = jsonDecode(response.body);
        if (decoded is! Map<String, dynamic>) {
          throw PubDevClientException(
            'Malformed JSON from $uri: expected an object.',
          );
        }
        return decoded;
      } on TimeoutException {
        if (attempt <= maxRetries) {
          final delay = Duration(milliseconds: 200 * (1 << (attempt - 1)));
          await Future<void>.delayed(delay);
          continue;
        }
        throw PubDevClientException(
          'Timed out requesting $uri after $timeout',
          timedOut: true,
        );
      } on PubDevClientException {
        rethrow;
      } on FormatException catch (e) {
        throw PubDevClientException('Malformed JSON from $uri: $e');
      } on http.ClientException catch (e) {
        if (attempt <= maxRetries) {
          final delay = Duration(milliseconds: 200 * (1 << (attempt - 1)));
          await Future<void>.delayed(delay);
          continue;
        }
        throw PubDevClientException('Network error requesting $uri: $e');
      }
    }
  }
}

/// Error from the pub.dev client.
class PubDevClientException implements Exception {
  /// Creates a client exception.
  PubDevClientException(
    this.message, {
    this.statusCode,
    this.timedOut = false,
  });

  /// Error message.
  final String message;

  /// HTTP status code, if any.
  final int? statusCode;

  /// Whether the request timed out.
  final bool timedOut;

  /// Whether this represents a 404.
  bool get isNotFound => statusCode == 404;

  /// Whether this is a retriable/network-class failure.
  bool get isNetworkFailure =>
      timedOut ||
      statusCode == 429 ||
      (statusCode != null && statusCode! >= 500) ||
      statusCode == null;

  @override
  String toString() => 'PubDevClientException: $message';
}
