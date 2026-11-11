import 'package:pub_health/src/config/pub_health_config.dart';
import 'package:pub_health/src/models/pub_health_options.dart';
import 'package:pub_health/src/models/severity.dart';
import 'package:pub_health/src/utils/yaml_utils.dart';
import 'package:test/test.dart';

void main() {
  test('parses ignore, severity, licenses, platforms and cache sections', () {
    final config = PubHealthConfig.parse('''
ignore:
  - legacy_only
  - package: foo
    rule: stale_package
    reason: vendored
    expires: 2027-03-01
severity:
  stale_package: low
licenses:
  allow: [MIT, BSD-3-Clause]
  deny: [GPL-3.0]
platforms: [Android, web]
wasm: true
baseline: base.json
cache:
  enabled: false
  dir: /tmp/x
  ttl-hours: 12
offline: true
recursive: true
exclude-projects: [examples/old]
''');
    expect(config.ignores, hasLength(2));
    expect(config.ignores.first.package, 'legacy_only');
    expect(config.ignores.last.rule, 'stale_package');
    expect(config.ignores.last.reason, 'vendored');
    expect(config.ignores.last.expires, DateTime.utc(2027, 3, 1));
    expect(config.severityOverrides['stale_package'], Severity.low);
    expect(config.allowedLicenses, {'mit', 'bsd-3-clause'});
    expect(config.deniedLicenses, {'gpl-3.0'});
    expect(config.platforms, {'android', 'web'});
    expect(config.requireWasm, isTrue);
    expect(config.baselinePath, 'base.json');
    expect(config.cacheEnabled, isFalse);
    expect(config.cacheDir, '/tmp/x');
    expect(config.cacheTtlHours, 12);
    expect(config.offline, isTrue);
    expect(config.recursive, isTrue);
    expect(config.excludeProjects, {'examples/old'});
  });

  test('rejects invalid values with a YamlParseException', () {
    expect(
      () => PubHealthConfig.parse('platforms: [amiga]'),
      throwsA(isA<YamlParseException>()),
    );
    expect(
      () => PubHealthConfig.parse('severity:\n  stale_package: urgent'),
      throwsFormatException,
    );
    expect(
      () => PubHealthConfig.parse('ignore:\n  - rule: x'),
      throwsA(isA<YamlParseException>()),
    );
    expect(
      () => PubHealthConfig.parse(
        'ignore:\n  - package: a\n    expires: someday',
      ),
      throwsA(isA<YamlParseException>()),
    );
    expect(
      () => PubHealthConfig.parse('ignore: nope'),
      throwsA(isA<YamlParseException>()),
    );
  });

  test('new report formats parse from config', () {
    for (final name in ['sarif', 'html', 'junit', 'badge']) {
      expect(
        PubHealthConfig.parse('report:\n  format: $name').format?.name,
        name,
      );
    }
  });

  test('merge: CLI beats config for cache/offline/baseline/recursive', () {
    final config = PubHealthConfig.parse('''
baseline: from_config.json
offline: true
recursive: true
cache:
  enabled: true
''');
    final merged = config.mergeWithCli(
      const PubHealthOptions(
        baselinePath: 'cli.json',
        offline: false,
        recursive: false,
        useCache: false,
      ),
      cliParsed: {'baseline', 'offline', 'recursive', 'cache'},
    );
    expect(merged.baselinePath, 'cli.json');
    expect(merged.offline, isFalse);
    expect(merged.recursive, isFalse);
    expect(merged.useCache, isFalse);

    final fromConfig = config.mergeWithCli(
      const PubHealthOptions(),
      cliParsed: {},
    );
    expect(fromConfig.baselinePath, 'from_config.json');
    expect(fromConfig.offline, isTrue);
    expect(fromConfig.recursive, isTrue);
  });

  test('ReportFormatX.parse is case-insensitive and rejects unknowns', () {
    expect(ReportFormatX.parse('SARIF'), ReportFormat.sarif);
    expect(() => ReportFormatX.parse('xml'), throwsFormatException);
  });
}
