import 'package:pub_health/src/clients/pub_dev_client.dart';
import 'package:test/test.dart';

import '../support/mock_pub_dev_client.dart';

void main() {
  test('fetches package and score successfully', () async {
    final client = mockPubDevClient(
      packages: {
        'http': packageJson(
          name: 'http',
          latestVersion: '1.2.2',
          sdkConstraint: '>=3.0.0 <4.0.0',
        ),
      },
    );
    final info = await client.fetchPackage('http');
    expect(info.latestVersion, '1.2.2');
    expect(info.score, isNotNull);
    expect(info.score!.grantedPoints, greaterThan(0));
    client.close();
  });

  test('caches package responses', () async {
    final client = mockPubDevClient(
      packages: {
        'http': packageJson(name: 'http', latestVersion: '1.0.0'),
      },
    );
    final a = await client.fetchPackage('http');
    final b = await client.fetchPackage('http');
    expect(identical(a, b), isTrue);
    client.close();
  });

  test('throws on 404', () async {
    final client = mockPubDevClient(packages: {});
    expect(
      () => client.fetchPackage('missing_pkg'),
      throwsA(
        isA<PubDevClientException>().having((e) => e.isNotFound, '404', isTrue),
      ),
    );
    client.close();
  });

  test('retries then fails on persistent 500', () async {
    final client = mockPubDevClient(
      packages: {
        'http': packageJson(name: 'http', latestVersion: '1.0.0'),
      },
      statusCodeOverride: 500,
    );
    expect(
      () => client.fetchPackage('http'),
      throwsA(isA<PubDevClientException>()),
    );
    client.close();
  });

  test('handles malformed JSON', () async {
    final client = mockPubDevClient(
      packages: {
        'http': packageJson(name: 'http', latestVersion: '1.0.0'),
      },
      malformedJson: true,
    );
    expect(
      () => client.fetchPackage('http'),
      throwsA(isA<PubDevClientException>()),
    );
    client.close();
  });

  test('works with custom base URL paths', () async {
    final client = mockPubDevClient(
      packages: {
        'path': packageJson(name: 'path', latestVersion: '1.9.0'),
      },
    );
    final info = await client.fetchPackage('path');
    expect(info.name, 'path');
    client.close();
  });
}
