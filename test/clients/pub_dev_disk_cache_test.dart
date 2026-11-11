import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:pub_health/src/clients/pub_dev_cache.dart';
import 'package:pub_health/src/clients/pub_dev_client.dart';
import 'package:pub_health/src/clients/pub_dev_disk_cache.dart';
import 'package:pub_health/src/models/pub_dev_package_info.dart';
import 'package:test/test.dart';

import '../support/mock_pub_dev_client.dart';

void main() {
  late Directory dir;
  var now = DateTime.utc(2026, 11, 10, 12);

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('pub_health_cache_');
    now = DateTime.utc(2026, 11, 10, 12);
  });
  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  PubDevDiskCache cache({Duration ttl = const Duration(hours: 6)}) =>
      PubDevDiskCache(
        directory: dir.path,
        baseUrl: 'https://pub.dev',
        ttl: ttl,
        clock: () => now,
      );

  final sample = PubDevPackageInfo(
    name: 'foo',
    latestVersion: '2.0.0',
    latestPublished: DateTime.utc(2026, 1, 2),
    discontinued: true,
    replacedBy: 'bar',
    sdkConstraint: '>=3.0.0 <4.0.0',
    versions: const [PubDevVersionInfo(version: '1.0.0', retracted: true)],
    score: const PubDevScoreInfo(
      grantedPoints: 150,
      maxPoints: 160,
      likeCount: 7,
      downloadCount30Days: 99,
      tags: ['license:mit', 'platform:web'],
    ),
  );

  test('round-trips every field', () async {
    final c = cache();
    await c.write('foo', sample);
    final read = await c.read('foo');
    expect(read, isNotNull);
    expect(read!.toJson(), sample.toJson());
    expect(read.isRetracted('1.0.0'), isTrue);
    expect(read.score!.tags, contains('license:mit'));
  });

  test('entries expire after the ttl unless stale reads are allowed', () async {
    final c = cache(ttl: const Duration(hours: 1));
    await c.write('foo', sample);
    now = now.add(const Duration(hours: 2));
    expect(await c.read('foo'), isNull);
    expect(await c.read('foo', allowStale: true), isNotNull);
  });

  test('corrupt and missing entries are treated as misses', () async {
    final c = cache();
    expect(await c.read('nothing'), isNull);
    await Directory(c.path).create(recursive: true);
    await File(p.join(c.path, 'bad.json')).writeAsString('{not json');
    expect(await c.read('bad'), isNull);
    await File(p.join(c.path, 'odd.json')).writeAsString('[]');
    expect(await c.read('odd'), isNull);
  });

  test('different pub hosts do not share entries', () async {
    final a = PubDevDiskCache(directory: dir.path, baseUrl: 'https://pub.dev');
    final b = PubDevDiskCache(
      directory: dir.path,
      baseUrl: 'https://pub.corp.example:8080',
    );
    await a.write('foo', sample);
    expect(await b.read('foo'), isNull);
    expect(b.path, isNot(a.path));
  });

  test('defaultDirectory honours environment precedence', () {
    expect(
      PubDevDiskCache.defaultDirectory({
        'PUB_HEALTH_CACHE_DIR': '/explicit',
        'XDG_CACHE_HOME': '/xdg',
        'HOME': '/home/u',
      }),
      '/explicit',
    );
    expect(
      PubDevDiskCache.defaultDirectory({
        'XDG_CACHE_HOME': '/xdg',
        'HOME': '/home/u',
      }),
      p.join('/xdg', 'pub_health'),
    );
    expect(
      PubDevDiskCache.defaultDirectory({'HOME': '/home/u'}),
      p.join('/home/u', '.cache', 'pub_health'),
    );
  });

  group('PubDevClient with disk cache', () {
    http.Client network(void Function() onCall, {int status = 200}) {
      return MockClient((request) async {
        onCall();
        if (status != 200) return http.Response('err', status);
        final segments = request.url.pathSegments;
        if (segments.length >= 4 && segments[3] == 'score') {
          return http.Response(
            jsonEncode({
              'grantedPoints': 100,
              'maxPoints': 160,
              'likeCount': 3,
              'downloadCount30Days': 4,
              'tags': ['license:mit'],
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode(packageJson(name: 'foo', latestVersion: '1.0.0')),
          200,
        );
      });
    }

    PubDevClient client(
      http.Client http, {
      bool offline = false,
      PubDevDiskCache? disk,
    }) =>
        PubDevClient(
          httpClient: http,
          cache: PubDevCache(),
          diskCache: disk ?? cache(),
          offline: offline,
          maxRetries: 0,
        );

    test('second client is served from disk without touching the network',
        () async {
      var calls = 0;
      await client(network(() => calls++)).fetchPackage('foo');
      final firstRunCalls = calls;
      expect(firstRunCalls, greaterThan(0));

      final info = await client(network(() => calls++)).fetchPackage('foo');
      expect(calls, firstRunCalls);
      expect(info.latestVersion, '1.0.0');
      expect(info.score!.tags, ['license:mit']);
    });

    test('offline mode serves stale cache and throws on a miss', () async {
      await cache().write('foo', sample);
      now = now.add(const Duration(days: 30));

      var calls = 0;
      final offline = client(network(() => calls++), offline: true);
      expect((await offline.fetchPackage('foo')).latestVersion, '2.0.0');
      expect(calls, 0);

      await expectLater(
        offline.fetchPackage('missing'),
        throwsA(isA<PubDevOfflineException>()),
      );
      expect(calls, 0);
    });

    test('falls back to stale cache when pub.dev is down, with a note',
        () async {
      await cache().write('foo', sample);
      now = now.add(const Duration(days: 3));

      final c = client(network(() {}, status: 503));
      final info = await c.fetchPackage('foo');
      expect(info.latestVersion, '2.0.0');
      expect(c.diagnostics.single, contains('using data cached on 2026-11-10'));
    });

    test('404 is never masked by a stale cache entry', () async {
      await cache().write('foo', sample);
      now = now.add(const Duration(days: 3));
      await expectLater(
        client(network(() {}, status: 404)).fetchPackage('foo'),
        throwsA(
          isA<PubDevClientException>().having((e) => e.isNotFound, '404', true),
        ),
      );
    });

    test('404s are cached: no repeat request, and offline stays quiet',
        () async {
      var calls = 0;
      final first = client(network(() => calls++, status: 404));
      await expectLater(
        first.fetchPackage('private_pkg'),
        throwsA(
          isA<PubDevClientException>().having((e) => e.isNotFound, '404', true),
        ),
      );
      final firstCalls = calls;
      expect(firstCalls, 1);

      final second = client(network(() => calls++));
      await expectLater(
        second.fetchPackage('private_pkg'),
        throwsA(
          isA<PubDevClientException>().having((e) => e.isNotFound, '404', true),
        ),
      );
      expect(calls, firstCalls, reason: 'served from the negative cache');

      // Offline: still a plain 404, not an offline-miss warning.
      now = now.add(const Duration(days: 30));
      final offline = client(network(() => calls++), offline: true);
      await expectLater(
        offline.fetchPackage('private_pkg'),
        throwsA(
          isA<PubDevClientException>().having((e) => e.isNotFound, '404', true),
        ),
      );
      expect(calls, firstCalls);
    });

    test('a cached 404 does not mask a later outage as stale data', () async {
      await expectLater(
        client(network(() {}, status: 404)).fetchPackage('x'),
        throwsA(isA<PubDevClientException>()),
      );
      now = now.add(const Duration(days: 3)); // expired
      await expectLater(
        client(network(() {}, status: 503)).fetchPackage('x'),
        throwsA(
          isA<PubDevClientException>()
              .having((e) => e.isNotFound, 'not a 404', false),
        ),
      );
    });

    test('network failure without any cache still throws', () async {
      await expectLater(
        client(network(() {}, status: 503)).fetchPackage('foo'),
        throwsA(isA<PubDevClientException>()),
      );
    });
  });
}
