import 'package:pub_health/src/models/health_finding.dart';
import 'package:pub_health/src/models/ignore_rule.dart';
import 'package:pub_health/src/models/severity.dart';
import 'package:pub_health/src/suppression/suppressor.dart';
import 'package:test/test.dart';

HealthFinding finding(String rule, String pkg, {String? project}) =>
    HealthFinding(
      ruleId: rule,
      package: pkg,
      severity: Severity.medium,
      title: 't',
      detail: 'd',
      recommendation: 'r',
      metadata: {if (project != null) 'project': project},
    );

void main() {
  final now = DateTime.utc(2026, 11, 10);
  const suppressor = Suppressor();

  test('ignore by package and rule', () {
    final result = suppressor.apply(
      [finding('stale_package', 'a'), finding('outdated_dependency', 'a')],
      ignores: const [IgnoreRule(package: 'a', rule: 'stale_package')],
      now: now,
    );
    expect(result.suppressed.map((f) => f.ruleId), ['stale_package']);
    expect(result.active.map((f) => f.ruleId), ['outdated_dependency']);
  });

  test('ignore without rule covers every rule; * covers every package', () {
    final all = suppressor.apply(
      [finding('stale_package', 'a'), finding('outdated_dependency', 'a')],
      ignores: const [IgnoreRule(package: 'a')],
      now: now,
    );
    expect(all.active, isEmpty);

    final wildcard = suppressor.apply(
      [finding('stale_package', 'a'), finding('stale_package', 'b')],
      ignores: const [IgnoreRule(package: '*', rule: 'stale_package')],
      now: now,
    );
    expect(wildcard.active, isEmpty);
  });

  test('expired ignores stop applying and produce a warning', () {
    final result = suppressor.apply(
      [finding('stale_package', 'a')],
      ignores: [
        IgnoreRule(
          package: 'a',
          reason: 'vendored',
          expires: DateTime.utc(2026, 11, 9),
        ),
      ],
      now: now,
    );
    expect(result.active, hasLength(1));
    expect(result.warnings.single, contains('expired on 2026-11-09'));
    expect(result.warnings.single, contains('vendored'));
  });

  test('ignore is still valid on its expiry day', () {
    final result = suppressor.apply(
      [finding('stale_package', 'a')],
      ignores: [IgnoreRule(package: 'a', expires: DateTime.utc(2026, 11, 10))],
      now: DateTime.utc(2026, 11, 10, 23, 0),
    );
    expect(result.active, isEmpty);
  });

  test('unused ignore entries are reported', () {
    final result = suppressor.apply(
      const [],
      ignores: const [IgnoreRule(package: 'ghost')],
      now: now,
    );
    expect(result.warnings.single, contains('matches no current finding'));
  });

  group('baseline', () {
    test('suppresses recorded findings, keeps new ones', () {
      final baseline = Baseline.parse(
        Baseline.encode([finding('stale_package', 'old')]),
      );
      final result = suppressor.apply(
        [finding('stale_package', 'old'), finding('stale_package', 'new')],
        ignores: const [],
        now: now,
        baseline: baseline,
      );
      expect(result.suppressed.map((f) => f.package), ['old']);
      expect(result.active.map((f) => f.package), ['new']);
    });

    test('warns about entries that no longer apply', () {
      final baseline = Baseline.parse(
        Baseline.encode([finding('stale_package', 'gone')]),
      );
      final result = suppressor.apply(
        const [],
        ignores: const [],
        now: now,
        baseline: baseline,
      );
      expect(result.warnings.single, contains('--update-baseline'));
    });

    test('keys include the project in recursive mode', () {
      final baseline = Baseline.parse(
        Baseline.encode([finding('stale_package', 'a', project: 'app')]),
      );
      final result = suppressor.apply(
        [
          finding('stale_package', 'a', project: 'app'),
          finding('stale_package', 'a', project: 'other'),
        ],
        ignores: const [],
        now: now,
        baseline: baseline,
      );
      expect(result.suppressed, hasLength(1));
      expect(result.active.single.metadata['project'], 'other');
    });

    test('encoding is deterministic and sorted', () {
      final a = Baseline.encode(
        [
          finding('b_rule', 'x'),
          finding('a_rule', 'z'),
          finding('a_rule', 'y')
        ],
        now: now,
      );
      final b = Baseline.encode(
        [
          finding('a_rule', 'y'),
          finding('b_rule', 'x'),
          finding('a_rule', 'z')
        ],
        now: now,
      );
      expect(a, b);
    });

    test('rejects malformed or newer-format baselines', () {
      expect(() => Baseline.parse('not json'), throwsFormatException);
      expect(() => Baseline.parse('{"x":1}'), throwsFormatException);
      expect(
        () => Baseline.parse('{"version":99,"findings":[]}'),
        throwsFormatException,
      );
    });
  });
}
