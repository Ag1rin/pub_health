import 'package:pub_health/src/config/pub_health_config.dart';
import 'package:pub_health/src/models/pub_health_options.dart';
import 'package:pub_health/src/models/severity.dart';
import 'package:test/test.dart';

void main() {
  test('parses pub_health.yaml fields', () {
    final config = PubHealthConfig.parse('''
fail-on: critical
stale-after-months: 24
include-transitive: false
exclude:
  - build_runner
  - test
disable-rules:
  - unused_dependency
timeout: 30
report:
  format: json
  output: report.json
''');

    expect(config.failOn, Severity.critical);
    expect(config.staleAfterMonths, 24);
    expect(config.includeTransitive, isFalse);
    expect(config.exclude, containsAll(['build_runner', 'test']));
    expect(config.disabledRules, contains('unused_dependency'));
    expect(config.timeoutSeconds, 30);
    expect(config.format, ReportFormat.json);
    expect(config.outputPath, 'report.json');
  });

  test('CLI flags override config values', () {
    final config = PubHealthConfig.parse('''
fail-on: low
stale-after-months: 6
report:
  format: markdown
''');

    final merged = config.mergeWithCli(
      const PubHealthOptions(
        failOn: Severity.critical,
        staleAfterMonths: 24,
        format: ReportFormat.json,
      ),
      cliParsed: {'fail-on', 'format'},
    );

    expect(merged.failOn, Severity.critical);
    expect(merged.format, ReportFormat.json);
    // Not provided on CLI → config wins.
    expect(merged.staleAfterMonths, 6);
  });

  test('config fills defaults when CLI omits flags', () {
    final config = PubHealthConfig.parse('''
fail-on: medium
exclude:
  - lints
''');

    final merged = config.mergeWithCli(
      const PubHealthOptions(),
      cliParsed: {},
    );

    expect(merged.failOn, Severity.medium);
    expect(merged.exclude, contains('lints'));
  });
}
