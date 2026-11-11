import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/pub_dev_package_info.dart';
import '../version.dart';
import 'pub_dev_cache.dart';
import 'pub_dev_disk_cache.dart';

/// Client for the public pub.dev API.
class PubDevClient {
  /// Creates a pub.dev client.
  PubDevClient({
    http.Client? httpClient,
    PubDevCache? cache,
    this.baseUrl = 'https://pub.dev',
    this.timeout = const Duration(seconds: 20),
    this.maxRetries = 3,
    PubDevDiskCache? diskCache,
    this.offline = false,
  })  : _httpClient = httpClient ?? http.Client(),
        _cache = cache ?? PubDevCache(),
        _diskCache = diskCache,
        _ownsClient = httpClient == null;

  /// API base URL (overridable for tests).
  final String baseUrl;

  /// Per-request timeout.
  final Duration timeout;

  /// Max retry attempts for 429 / 5xx.
  final int maxRetries;

  /// When true, the network is never used; only cached data is served.
  final bool offline;

  /// Non-fatal notes collected while fetching (stale cache fallbacks, …).
  final List<String> diagnostics = [];

  final http.Client _httpClient;
  final PubDevCache _cache;
  final PubDevDiskCache? _diskCache;
  final bool _ownsClient;

  /// Fetches package metadata and score.
  ///
  /// Lookup order: in-memory cache → fresh on-disk cache → network. If the
  /// network fails for a reason other than "not found", a stale on-disk entry
  /// is used (with a note in [diagnostics]) rather than failing the run.
  Future<PubDevPackageInfo> fetchPackage(String name) async {
    final cached = _cache.getPackage(name);
    if (cached != null) return cached;

    final disk = _diskCache;
    if (disk != null) {
      final fresh = await disk.read(name, allowStale: offline);
      if (fresh != null) {
        // A cached "not found" must behave exactly like a live 404.
        if (fresh.notFound) throw _notFound(name);
        _cache.putPackage(name, fresh);
        return fresh;
      }
    }

    if (offline) {
      throw PubDevOfflineException(name);
    }

    try {
      final info = await _fetchFromNetwork(name);
      await disk?.write(name, info);
      return info;
    } on PubDevClientException catch (e) {
      if (e.isNotFound) {
        // Remember misses (private / unpublished packages) so repeat and
        // offline runs neither re-request them nor warn about them.
        await disk?.write(
          name,
          PubDevPackageInfo(name: name, latestVersion: '', notFound: true),
        );
        rethrow;
      }
      if (disk == null) rethrow;
      final stale = await disk.readEntry(name);
      if (stale == null || stale.info.notFound) rethrow;
      diagnostics.add(
        'pub.dev was unreachable for $name; using data cached on '
        '${stale.cachedAt.toIso8601String().substring(0, 10)}.',
      );
      _cache.putPackage(name, stale.info);
      return stale.info;
    }
  }

  PubDevClientException _notFound(String name) => PubDevClientException(
        'Package not found: $name (cached)',
        statusCode: 404,
      );

  Future<PubDevPackageInfo> _fetchFromNetwork(String name) async {
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
            'User-Agent': 'pub_health/$pubHealthVersion',
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

/// Raised in offline mode when a package is not in the on-disk cache.
class PubDevOfflineException extends PubDevClientException {
  /// Creates an offline-miss exception for [package].
  PubDevOfflineException(this.package)
      : super('Offline mode: no cached pub.dev data for $package.');

  /// Package that was not cached.
  final String package;
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
