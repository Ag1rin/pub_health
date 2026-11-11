import 'package:pub_health/src/models/dependency.dart';
import 'package:pub_health/src/models/dependency_kind.dart';
import 'package:pub_health/src/models/dependency_override.dart';
import 'package:pub_health/src/models/pub_dev_package_info.dart';
import 'package:pub_health/src/models/pub_health_options.dart';
import 'package:pub_health/src/models/severity.dart';
import 'package:pub_health/src/rules/dependency_override_rule.dart';
import 'package:pub_health/src/rules/git_dependency_rule.dart';
import 'package:pub_health/src/rules/license_rule.dart';
import 'package:pub_health/src/rules/misplaced_dependency_rule.dart';
import 'package:pub_health/src/rules/platform_support_rule.dart';
import 'package:pub_health/src/rules/rule.dart';
import 'package:pub_health/src/rules/rule_engine.dart';
import 'package:pub_health/src/rules/unconstrained_dependency_rule.dart';
import 'package:pub_health/src/rules/unverified_publisher_rule.dart';
import 'package:test/test.dart';

import '../support/mock_pub_dev_client.dart';

RuleContext ctx({
  List<Dependency> deps = const [],
  Map<String, PubDevPackageInfo> infos = const {},
  List<DependencyOverride> overrides = const [],
  Set<String> production = const {},
  PubHealthOptions options = const PubHealthOptions(),
  bool flutter = false,
}) =>
    RuleContext(
      projectPath: '.',
      dependencies: deps,
      packageInfo: infos,
      unusedPackages: const {},
      options: options,
      overrides: overrides,
      productionImports: production,
      isFlutter: flutter,
    );

PubDevPackageInfo withTags(
  String name,
  List<String> tags, {
  int likes = 5000,
}) =>
    info(
      name: name,
      latestVersion: '1.0.0',
      score: PubDevScoreInfo(
        grantedPoints: 150,
        maxPoints: 160,
        likeCount: likes,
        tags: tags,
      ),
    );

void main() {
  group('dependency_override', () {
    test('flags hosted/git overrides as medium and path as low', () {
      final findings = const DependencyOverrideRule().evaluate(
        ctx(
          overrides: const [
            DependencyOverride(
              name: 'a',
              source: 'hosted',
              constraint: '1.2.3',
              declaredLine: 12,
            ),
            DependencyOverride(
              name: 'b',
              source: 'git',
              sourceUrl: 'https://example.com/b.git',
            ),
            DependencyOverride(name: 'c', source: 'path', sourceUrl: '../c'),
          ],
        ),
      );
      final bySeverity = {for (final f in findings) f.package: f.severity};
      expect(bySeverity['a'], Severity.medium);
      expect(bySeverity['b'], Severity.medium);
      expect(bySeverity['c'], Severity.low);
      expect(findings.first.metadata['line'], 12);
    });

    test('honours exclude', () {
      final findings = const DependencyOverrideRule().evaluate(
        ctx(
          overrides: const [DependencyOverride(name: 'a', source: 'hosted')],
          options: const PubHealthOptions(exclude: {'a'}),
        ),
      );
      expect(findings, isEmpty);
    });
  });

  group('git_dependency', () {
    test('flags declared git deps but not transitive ones', () {
      final findings = const GitDependencyRule().evaluate(
        ctx(
          deps: const [
            Dependency(
              name: 'g',
              kind: DependencyKind.direct,
              source: 'git',
              sourceUrl: 'https://example.com/g.git',
            ),
            Dependency(
              name: 't',
              kind: DependencyKind.transitive,
              source: 'git',
            ),
            Dependency(name: 'h', kind: DependencyKind.direct),
          ],
        ),
      );
      expect(findings.map((f) => f.package), ['g']);
      expect(findings.single.severity, Severity.low);
      expect(findings.single.detail, contains('example.com'));
    });
  });

  group('unconstrained_dependency', () {
    Dependency dep(String n, String? c,
            [DependencyKind k = DependencyKind.direct]) =>
        Dependency(name: n, kind: k, constraint: c);

    test('flags any / missing / open-ended constraints', () {
      final findings = const UnconstrainedDependencyRule().evaluate(
        ctx(
          deps: [
            dep('any_pkg', 'any'),
            dep('none_pkg', null),
            dep('open_pkg', '>=1.2.0'),
            dep('caret_pkg', '^1.2.0'),
            dep('range_pkg', '>=1.0.0 <2.0.0'),
            dep('pinned_pkg', '1.2.3'),
          ],
        ),
      );
      final map = {for (final f in findings) f.package: f.severity};
      expect(map['any_pkg'], Severity.medium);
      expect(map['none_pkg'], Severity.medium);
      expect(map['open_pkg'], Severity.low);
      expect(map.containsKey('caret_pkg'), isFalse);
      expect(map.containsKey('range_pkg'), isFalse);
      expect(map.containsKey('pinned_pkg'), isFalse);
    });

    test('dev deps are only flagged (low) for any, never for open bounds', () {
      final findings = const UnconstrainedDependencyRule().evaluate(
        ctx(
          deps: [
            dep('d1', 'any', DependencyKind.dev),
            dep('d2', '>=1.0.0', DependencyKind.dev),
          ],
        ),
      );
      expect(findings.map((f) => f.package), ['d1']);
      expect(findings.single.severity, Severity.low);
    });

    test('ignores sdk, git, path and transitive dependencies', () {
      final findings = const UnconstrainedDependencyRule().evaluate(
        ctx(
          deps: const [
            Dependency(
              name: 'flutter',
              kind: DependencyKind.direct,
              isSdk: true,
              source: 'sdk',
            ),
            Dependency(name: 'g', kind: DependencyKind.direct, source: 'git'),
            Dependency(name: 'p', kind: DependencyKind.direct, source: 'path'),
            Dependency(name: 't', kind: DependencyKind.transitive),
          ],
        ),
      );
      expect(findings, isEmpty);
    });
  });

  group('misplaced_dependency', () {
    test('dev dependency imported from lib/ is flagged', () {
      final findings = const MisplacedDependencyRule().evaluate(
        ctx(
          deps: const [
            Dependency(name: 'collection', kind: DependencyKind.dev),
            Dependency(name: 'unused_dev', kind: DependencyKind.dev),
          ],
          production: {'collection'},
        ),
      );
      expect(findings.map((f) => f.package), ['collection']);
      expect(findings.single.severity, Severity.medium);
      expect(
        findings.single.metadata['suggestedCommand'],
        contains('dart pub add collection'),
      );
    });

    test('tooling package under dependencies is flagged unless imported', () {
      const deps = [
        Dependency(name: 'mocktail', kind: DependencyKind.direct),
        Dependency(name: 'test', kind: DependencyKind.direct),
        Dependency(name: 'http', kind: DependencyKind.direct),
      ];
      final findings = const MisplacedDependencyRule().evaluate(
        ctx(deps: deps, production: {'test'}, flutter: true),
      );
      expect(findings.map((f) => f.package), ['mocktail']);
      expect(findings.single.severity, Severity.low);
      expect(
        findings.single.metadata['suggestedCommand'],
        startsWith('flutter pub'),
      );
    });
  });

  group('license_risk', () {
    Dependency dep(String n) => Dependency(
        name: n, kind: DependencyKind.direct, lockedVersion: '1.0.0');

    test('licensesFromTags ignores classification tags', () {
      expect(
        LicenseRule.licensesFromTags(const [
          'license:mit',
          'license:osi-approved',
          'license:fsf-libre',
          'platform:web',
        ]),
        {'mit'},
      );
    });

    test('never judges packages with no tag data', () {
      final findings = const LicenseRule().evaluate(
        ctx(
          deps: [dep('a')],
          infos: {'a': withTags('a', const [])},
        ),
      );
      expect(findings, isEmpty);
    });

    test('flags unknown / missing license as medium', () {
      final findings = const LicenseRule().evaluate(
        ctx(
          deps: [dep('a'), dep('b'), dep('c')],
          infos: {
            'a': withTags('a', const ['license:unknown', 'sdk:dart']),
            'b': withTags('b', const ['sdk:dart']),
            'c': withTags('c', const ['license:mit', 'sdk:dart']),
          },
        ),
      );
      expect(findings.map((f) => f.package), unorderedEquals(['a', 'b']));
      expect(findings.every((f) => f.severity == Severity.medium), isTrue);
    });

    test('denied license is high, allow-list violations are high', () {
      final findings = const LicenseRule().evaluate(
        ctx(
          deps: [dep('gpl'), dep('bsd'), dep('mit')],
          infos: {
            'gpl': withTags('gpl', const ['license:gpl-3.0']),
            'bsd': withTags('bsd', const ['license:bsd-3-clause']),
            'mit': withTags('mit', const ['license:mit']),
          },
          options: const PubHealthOptions(
            deniedLicenses: {'gpl-3.0'},
            allowedLicenses: {'mit'},
          ),
        ),
      );
      final map = {for (final f in findings) f.package: f};
      expect(map.keys, unorderedEquals(['gpl', 'bsd']));
      expect(map['gpl']!.detail, contains('denied'));
      expect(map['bsd']!.detail, contains('not in the allowed list'));
      expect(map['gpl']!.severity, Severity.high);
    });

    test('multi-license packages must have every license allowed', () {
      final findings = const LicenseRule().evaluate(
        ctx(
          deps: [dep('multi')],
          infos: {
            'multi':
                withTags('multi', const ['license:mit', 'license:gpl-2.0']),
          },
          options: const PubHealthOptions(allowedLicenses: {'mit'}),
        ),
      );
      expect(findings, hasLength(1));
    });
  });

  group('platform_support', () {
    Dependency dep(String n, [DependencyKind k = DependencyKind.direct]) =>
        Dependency(name: n, kind: k);

    test('is inert without configuration', () {
      final findings = const PlatformSupportRule().evaluate(
        ctx(
          deps: [dep('a')],
          infos: {
            'a': withTags('a', const ['platform:android']),
          },
        ),
      );
      expect(findings, isEmpty);
    });

    test('flags missing target platforms (medium)', () {
      final findings = const PlatformSupportRule().evaluate(
        ctx(
          deps: [dep('a'), dep('b')],
          infos: {
            'a': withTags('a', const ['platform:android', 'platform:ios']),
            'b': withTags('b', const [
              'platform:android',
              'platform:ios',
              'platform:web',
            ]),
          },
          options: const PubHealthOptions(
            platforms: {'android', 'ios', 'web'},
          ),
        ),
      );
      expect(findings.map((f) => f.package), ['a']);
      expect(findings.single.severity, Severity.medium);
      expect(findings.single.metadata['missingPlatforms'], ['web']);
    });

    test('skips packages with no platform tags and dev/transitive deps', () {
      final findings = const PlatformSupportRule().evaluate(
        ctx(
          deps: [
            dep('tool'),
            dep('d', DependencyKind.dev),
            dep('t', DependencyKind.transitive),
          ],
          infos: {
            'tool': withTags('tool', const ['sdk:dart']),
            'd': withTags('d', const ['platform:android']),
            't': withTags('t', const ['platform:android']),
          },
          options: const PubHealthOptions(platforms: {'web'}),
        ),
      );
      expect(findings, isEmpty);
    });

    test('wasm-only gap is low and combines with platform gaps', () {
      final wasmOnly = const PlatformSupportRule().evaluate(
        ctx(
          deps: [dep('a')],
          infos: {
            'a': withTags('a', const ['platform:web', 'is:null-safe']),
          },
          options: const PubHealthOptions(requireWasm: true),
        ),
      );
      expect(wasmOnly.single.severity, Severity.low);

      final both = const PlatformSupportRule().evaluate(
        ctx(
          deps: [dep('a')],
          infos: {
            'a': withTags('a', const ['platform:android']),
          },
          options: const PubHealthOptions(
            platforms: {'web'},
            requireWasm: true,
          ),
        ),
      );
      expect(both, hasLength(1));
      expect(both.single.severity, Severity.medium);
      expect(both.single.detail, contains('WebAssembly'));
    });
  });

  group('unverified_publisher', () {
    Dependency dep(String n) =>
        Dependency(name: n, kind: DependencyKind.direct);

    test('flags unpopular packages with no publisher tag only', () {
      final findings = const UnverifiedPublisherRule().evaluate(
        ctx(
          deps: [dep('small'), dep('verified'), dep('popular'), dep('notags')],
          infos: {
            'small': withTags('small', const ['sdk:dart'], likes: 3),
            'verified': withTags(
              'verified',
              const ['publisher:example.com'],
              likes: 3,
            ),
            'popular': withTags('popular', const ['sdk:dart'], likes: 900),
            'notags': withTags('notags', const [], likes: 1),
          },
        ),
      );
      expect(findings.map((f) => f.package), ['small']);
    });
  });

  group('rule engine', () {
    test('severity overrides are applied', () {
      final findings =
          RuleEngine(rules: const [DependencyOverrideRule()]).evaluate(
        ctx(
          overrides: const [DependencyOverride(name: 'a', source: 'hosted')],
          options: const PubHealthOptions(
            severityOverrides: {'dependency_override': Severity.critical},
          ),
        ),
      );
      expect(findings.single.severity, Severity.critical);
    });

    test('default rule set contains every new rule exactly once', () {
      final ids = RuleEngine.defaultRuleIds;
      expect(
        ids,
        containsAll([
          'dependency_override',
          'git_dependency',
          'unconstrained_dependency',
          'misplaced_dependency',
          'license_risk',
          'platform_support',
          'unverified_publisher',
        ]),
      );
      expect(ids.toSet(), hasLength(ids.length));
    });
  });
}
