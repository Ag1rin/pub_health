import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pub_health/src/clients/pub_dev_cache.dart';
import 'package:pub_health/src/clients/pub_dev_client.dart';
import 'package:pub_health/src/models/pub_dev_package_info.dart';

/// Builds a [PubDevClient] backed by canned JSON responses.
PubDevClient mockPubDevClient({
  required Map<String, Map<String, dynamic>> packages,
  Map<String, Map<String, dynamic>>? scores,
  int? statusCodeOverride,
  bool malformedJson = false,
  bool timeout = false,
  List<int>? statusSequence,
}) {
  var callIndex = 0;
  final client = MockClient((request) async {
    if (timeout) {
      throw TimeoutException('simulated timeout');
    }
    if (statusSequence != null && callIndex < statusSequence.length) {
      final code = statusSequence[callIndex++];
      if (code != 200) {
        return http.Response('error', code);
      }
    } else if (statusCodeOverride != null && statusCodeOverride != 200) {
      return http.Response('error', statusCodeOverride);
    }

    if (malformedJson) {
      return http.Response('not-json', 200);
    }

    final segments = request.url.pathSegments;
    // /api/packages/<name> or /api/packages/<name>/score
    if (segments.length >= 3 &&
        segments[0] == 'api' &&
        segments[1] == 'packages') {
      final name = segments[2];
      if (segments.length >= 4 && segments[3] == 'score') {
        final score = scores?[name] ??
            {
              'grantedPoints': 130,
              'maxPoints': 160,
              'likeCount': 1000,
              'downloadCount30Days': 100000,
              'tags': <String>[],
            };
        return http.Response(jsonEncode(score), 200, headers: {
          'content-type': 'application/json',
        });
      }
      final package = packages[name];
      if (package == null) {
        return http.Response('not found', 404);
      }
      return http.Response(jsonEncode(package), 200, headers: {
        'content-type': 'application/json',
      });
    }
    return http.Response('not found', 404);
  });

  return PubDevClient(
    httpClient: client,
    cache: PubDevCache(),
    baseUrl: 'https://pub.dev',
    timeout: const Duration(seconds: 2),
    maxRetries: 2,
  );
}

/// Convenience package JSON builder for tests.
Map<String, dynamic> packageJson({
  required String name,
  required String latestVersion,
  String? published,
  bool discontinued = false,
  String? replacedBy,
  String? sdkConstraint,
  List<Map<String, dynamic>>? versions,
}) {
  final versionList = versions ??
      [
        {
          'version': latestVersion,
          'retracted': false,
          'published': published ?? '2025-01-01T00:00:00.000Z',
        },
      ];
  return {
    'name': name,
    'isDiscontinued': discontinued,
    if (replacedBy != null) 'replacedBy': replacedBy,
    'latest': {
      'version': latestVersion,
      'published': published ?? '2025-01-01T00:00:00.000Z',
      'pubspec': {
        'name': name,
        'version': latestVersion,
        'environment': {
          if (sdkConstraint != null) 'sdk': sdkConstraint,
        },
      },
    },
    'versions': versionList,
  };
}

/// Builds canned responses for the risky fixture project.
PubDevClient riskyFixtureClient({DateTime? now}) {
  final stalePublished = (now ?? DateTime.utc(2026, 10, 20))
      .subtract(const Duration(days: 600))
      .toIso8601String();

  return mockPubDevClient(
    packages: {
      'outdated_pkg': packageJson(
        name: 'outdated_pkg',
        latestVersion: '2.0.0',
        published: '2026-01-01T00:00:00.000Z',
        sdkConstraint: '>=3.0.0 <4.0.0',
        versions: [
          {
            'version': '1.0.0',
            'retracted': false,
            'published': '2024-01-01T00:00:00.000Z',
          },
          {
            'version': '2.0.0',
            'retracted': false,
            'published': '2026-01-01T00:00:00.000Z',
          },
        ],
      ),
      'discontinued_pkg': packageJson(
        name: 'discontinued_pkg',
        latestVersion: '1.0.0',
        discontinued: true,
        replacedBy: 'better_pkg',
        sdkConstraint: '>=3.0.0 <4.0.0',
      ),
      'retracted_pkg': packageJson(
        name: 'retracted_pkg',
        latestVersion: '1.1.0',
        sdkConstraint: '>=3.0.0 <4.0.0',
        versions: [
          {
            'version': '1.0.0',
            'retracted': true,
            'published': '2025-01-01T00:00:00.000Z',
          },
          {
            'version': '1.1.0',
            'retracted': false,
            'published': '2025-06-01T00:00:00.000Z',
          },
        ],
      ),
      'stale_pkg': packageJson(
        name: 'stale_pkg',
        latestVersion: '1.0.0',
        published: stalePublished,
        sdkConstraint: '>=3.0.0 <4.0.0',
      ),
      'unused_pkg': packageJson(
        name: 'unused_pkg',
        latestVersion: '1.0.0',
        sdkConstraint: '>=3.0.0 <4.0.0',
      ),
      'low_score_pkg': packageJson(
        name: 'low_score_pkg',
        latestVersion: '1.0.0',
        sdkConstraint: '>=3.0.0 <4.0.0',
      ),
      'sdk_risk_pkg': packageJson(
        name: 'sdk_risk_pkg',
        latestVersion: '1.0.0',
        sdkConstraint: '>=2.12.0 <3.0.0',
      ),
      'test': packageJson(
        name: 'test',
        latestVersion: '1.25.8',
        sdkConstraint: '>=3.0.0 <4.0.0',
      ),
      'transitive_helper': packageJson(
        name: 'transitive_helper',
        latestVersion: '0.1.0',
        sdkConstraint: '>=3.0.0 <4.0.0',
      ),
    },
    scores: {
      'outdated_pkg': _goodScore(),
      'discontinued_pkg': _goodScore(),
      'retracted_pkg': _goodScore(),
      'stale_pkg': {
        'grantedPoints': 100,
        'maxPoints': 160,
        'likeCount': 10,
        'downloadCount30Days': 100,
        'tags': <String>[],
      },
      'unused_pkg': _goodScore(),
      'low_score_pkg': {
        'grantedPoints': 20,
        'maxPoints': 160,
        'likeCount': 1,
        'downloadCount30Days': 5,
        'tags': <String>[],
      },
      'sdk_risk_pkg': _goodScore(),
      'test': _goodScore(),
      'transitive_helper': _goodScore(),
    },
  );
}

/// Builds canned responses for the healthy fixture.
PubDevClient healthyFixtureClient() {
  return mockPubDevClient(
    packages: {
      'path': packageJson(
        name: 'path',
        latestVersion: '1.9.0',
        sdkConstraint: '>=3.0.0 <4.0.0',
      ),
      'collection': packageJson(
        name: 'collection',
        latestVersion: '1.19.0',
        sdkConstraint: '>=3.0.0 <4.0.0',
      ),
      'test': packageJson(
        name: 'test',
        latestVersion: '1.25.8',
        sdkConstraint: '>=3.0.0 <4.0.0',
      ),
      'matcher': packageJson(
        name: 'matcher',
        latestVersion: '0.12.16',
        sdkConstraint: '>=3.0.0 <4.0.0',
      ),
    },
  );
}

Map<String, dynamic> _goodScore() => {
      'grantedPoints': 140,
      'maxPoints': 160,
      'likeCount': 2000,
      'downloadCount30Days': 200000,
      'tags': <String>[],
    };

/// Builds a [PubDevPackageInfo] for unit tests without HTTP.
PubDevPackageInfo info({
  required String name,
  required String latestVersion,
  DateTime? latestPublished,
  bool discontinued = false,
  String? sdkConstraint,
  List<PubDevVersionInfo> versions = const [],
  PubDevScoreInfo? score,
}) {
  return PubDevPackageInfo(
    name: name,
    latestVersion: latestVersion,
    latestPublished: latestPublished,
    discontinued: discontinued,
    versions: versions,
    sdkConstraint: sdkConstraint,
    score: score,
  );
}
