import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:pub_health/pub_health.dart';
import 'package:pub_health/src/clients/pub_dev_client.dart';
import 'package:test/test.dart';

import '../support/mock_pub_dev_client.dart';
import '../support/temp_project.dart';

final _now = DateTime.utc(2026, 11, 10);

PubDevClient clientFor(Map<String, List<String>> tagsByPackage) {
  return mockPubDevClient(
    packages: {
      for (final name in tagsByPackage.keys)
        name: packageJson(
          name: name,
          latestVersion: '1.0.0',
          published: '2026-10-01T00:00:00.000Z',
          sdkConstraint: '>=3.0.0 <4.0.0',
        ),
    },
    scores: {
      for (final e in tagsByPackage.entries)
        e.key: {
          'grantedPoints': 150,
          'maxPoints': 160,
          'likeCount': 5000,
          'downloadCount30Days': 900000,
          'tags': e.value,
        },
    },
  );
}

const _pubspec = '''
name: demo
environment:
  sdk: ^3.5.0
dependencies:
  alpha: any
  beta: ^1.0.0
  mocktail: ^1.0.0
dev_dependencies:
  gamma: ^1.0.0
dependency_overrides:
  beta: 1.0.0
''';

String get _lock => lockFile([
      lockEntry('alpha', '1.0.0'),
      lockEntry('beta', '1.0.0'),
      lockEntry('mocktail', '1.0.0'),
      lockEntry('gamma', '1.0.0', dependency: 'direct dev'),
    ]);

const _sources = {
  'lib/main.dart': "import 'package:alpha/alpha.dart';\n"
      "import 'package:beta/beta.dart';\n"
      "import 'package:gamma/gamma.dart';\n",
};

void main() {
  late Directory dir;
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('pub_health_it_');
    dir = await createTempProject(
      parent: tmp,
      subdir: 'proj',
      pubspec: _pubspec,
      lock: _lock,
      files: _sources,
    );
  });
  tearDown(() => tmp.delete(recursive: true));

  PubHealthOptions opts({
    String? baseline,
    bool update = false,
    String? compareTo,
    List<IgnoreRule> ignores = const [],
    Map<String, Severity> overrides = const {},
  }) =>
      PubHealthOptions(
        now: _now,
        color: false,
        baselinePath: baseline,
        updateBaseline: update,
        compareTo: compareTo,
        ignores: ignores,
        severityOverrides: overrides,
      );

  PubDevClient client() => clientFor({
        'alpha': ['license:mit', 'sdk:dart', 'publisher:x.dev'],
        'beta': ['license:unknown', 'sdk:dart', 'publisher:x.dev'],
        'mocktail': ['license:mit', 'sdk:dart', 'publisher:x.dev'],
        'gamma': ['license:mit', 'sdk:dart', 'publisher:x.dev'],
      });

  test('new rules fire end-to-end with locations and fix commands', () async {
    final report = await analyzeProject(
      dir.path,
      options: opts(),
      client: client(),
    );
    final byRule = <String, List<HealthFinding>>{};
    for (final f in report.findings) {
      byRule.putIfAbsent(f.ruleId, () => []).add(f);
    }

    expect(byRule['unconstrained_dependency']!.single.package, 'alpha');
    expect(byRule['dependency_override']!.single.package, 'beta');
    expect(byRule['misplaced_dependency']!.map((f) => f.package),
        unorderedEquals(['gamma', 'mocktail']));
    expect(byRule['license_risk']!.single.package, 'beta');

    final unconstrained = byRule['unconstrained_dependency']!.single;
    expect(unconstrained.metadata['file'], 'pubspec.yaml');
    expect(unconstrained.metadata['line'], 5); // `alpha: any`
    final override = byRule['dependency_override']!.single;
    expect(override.metadata['line'], 11);

    expect(report.healthScore.categories.keys, contains('hygiene'));
    expect(report.healthScore.categories.keys, contains('licensing'));
  });

  test('severity overrides and ignores change the report', () async {
    final report = await analyzeProject(
      dir.path,
      options: opts(
        overrides: {'dependency_override': Severity.critical},
        ignores: const [IgnoreRule(package: 'alpha')],
      ),
      client: client(),
    );
    expect(
      report.findings
          .firstWhere((f) => f.ruleId == 'dependency_override')
          .severity,
      Severity.critical,
    );
    expect(report.findings.where((f) => f.package == 'alpha'), isEmpty);
    expect(report.suppressed.any((f) => f.package == 'alpha'), isTrue);
  });

  test('baseline: write, then only new findings surface', () async {
    final baselinePath = p.join(tmp.path, 'base.json');

    final written = await analyzeProject(
      dir.path,
      options: opts(baseline: baselinePath, update: true),
      client: client(),
    );
    expect(written.findings, isEmpty);
    expect(written.suppressed, isNotEmpty);
    expect(written.warnings.join(), contains('Baseline written'));
    expect(File(baselinePath).existsSync(), isTrue);

    final clean = await analyzeProject(
      dir.path,
      options: opts(baseline: baselinePath),
      client: client(),
    );
    expect(clean.findings, isEmpty);
    expect(clean.healthScore.score, 100);

    // Introduce a new problem: a git dependency.
    await File(p.join(dir.path, 'pubspec.yaml')).writeAsString(
      '$_pubspec  fresh:\n    git: https://example.com/f.git\n',
    );
    final after = await analyzeProject(
      dir.path,
      options: opts(baseline: baselinePath),
      client: client(),
    );
    // `fresh` was appended under dependency_overrides, so it is a new override.
    expect(after.findings.map((f) => f.package), contains('fresh'));
    expect(after.findings.any((f) => f.package == 'beta'), isFalse);
  });

  test('missing or invalid baseline is a clear error', () async {
    await expectLater(
      analyzeProject(
        dir.path,
        options: opts(baseline: p.join(tmp.path, 'nope.json')),
        client: client(),
      ),
      throwsA(
        isA<ProjectAnalysisException>()
            .having((e) => e.message, 'message', contains('not found')),
      ),
    );

    final bad = File(p.join(tmp.path, 'bad.json'))..writeAsStringSync('{');
    await expectLater(
      analyzeProject(
        dir.path,
        options: opts(baseline: bad.path),
        client: client(),
      ),
      throwsA(
        isA<ProjectAnalysisException>()
            .having((e) => e.message, 'message', contains('Invalid baseline')),
      ),
    );
  });

  test('--update-baseline without a path is rejected', () async {
    await expectLater(
      analyzeProject(
        dir.path,
        options: opts(update: true),
        client: client(),
      ),
      throwsA(isA<ProjectAnalysisException>()),
    );
  });

  test('compare-to reports score delta, new and resolved findings', () async {
    final before = await analyzeProject(
      dir.path,
      options: opts(),
      client: client(),
    );
    final prev = File(p.join(tmp.path, 'prev.json'))
      ..writeAsStringSync(jsonEncode(before.toJson()));

    // Fix the `any` constraint and the override.
    await File(p.join(dir.path, 'pubspec.yaml')).writeAsString(
      _pubspec
          .replaceFirst('alpha: any', 'alpha: ^1.0.0')
          .replaceFirst('dependency_overrides:\n  beta: 1.0.0\n', ''),
    );
    final after = await analyzeProject(
      dir.path,
      options: opts(compareTo: prev.path),
      client: client(),
    );
    final cmp = after.comparison!;
    expect(cmp.previousScore, before.healthScore.score);
    expect(cmp.delta, greaterThan(0));
    expect(
      cmp.resolvedFindings,
      containsAll(
          ['unconstrained_dependency|alpha', 'dependency_override|beta']),
    );
    expect(cmp.newFindings, isEmpty);
    expect(after.toJson()['comparison'], isA<Map>());
  });

  test('compare-to rejects non-reports', () async {
    final bogus = File(p.join(tmp.path, 'x.json'))..writeAsStringSync('[]');
    await expectLater(
      analyzeProject(
        dir.path,
        options: opts(compareTo: bogus.path),
        client: client(),
      ),
      throwsA(isA<ProjectAnalysisException>()),
    );
    await expectLater(
      analyzeProject(
        dir.path,
        options: opts(compareTo: p.join(tmp.path, 'missing.json')),
        client: client(),
      ),
      throwsA(isA<ProjectAnalysisException>()),
    );
  });

  test('unknown rule ids in config produce warnings', () async {
    final report = await analyzeProject(
      dir.path,
      options: PubHealthOptions(
        now: _now,
        color: false,
        disabledRules: const {'stale_pakage'},
        severityOverrides: const {'nope': Severity.low},
        ignores: const [IgnoreRule(package: 'a', rule: 'typo_rule')],
      ),
      client: client(),
    );
    final joined = report.warnings.join('\n');
    expect(joined, contains('"stale_pakage"'));
    expect(joined, contains('"nope"'));
    expect(joined, contains('"typo_rule"'));
  });

  test('missing lockfile is surfaced as a warning', () async {
    File(p.join(dir.path, 'pubspec.lock')).deleteSync();
    final report = await analyzeProject(
      dir.path,
      options: opts(),
      client: client(),
    );
    expect(report.warnings.join(), contains('No pubspec.lock'));
  });

  group('recursive / workspace', () {
    test('analyzes every project, tags findings, scores the weakest', () async {
      await createTempProject(
        parent: tmp,
        subdir: 'packages/clean',
        pubspec: 'name: clean\ndependencies:\n  alpha: ^1.0.0\n',
        lock: lockFile([lockEntry('alpha', '1.0.0')]),
        files: {'lib/c.dart': "import 'package:alpha/alpha.dart';\n"},
      );
      // Must be skipped: hidden dir, build output.
      await createTempProject(
        parent: tmp,
        subdir: '.dart_tool/x',
        pubspec: 'name: hidden\n',
      );
      await createTempProject(
        parent: tmp,
        subdir: 'build/y',
        pubspec: 'name: built\n',
      );

      final report = await analyzeProject(
        tmp.path,
        options: opts().copyWith(recursive: true),
        client: client(),
      );
      expect(report.projects, ['packages/clean', 'proj']);
      final projects =
          report.findings.map((f) => f.metadata['project']).toSet();
      expect(projects, {'proj'});
      expect(
        report.healthScore.score,
        lessThan(100),
        reason: 'worst project (proj) must drive the score',
      );
      expect(report.toJson()['projects'], ['packages/clean', 'proj']);
    });

    test('exclude-projects skips a subtree', () async {
      // Only `proj` exists, so excluding it leaves nothing to analyze.
      await expectLater(
        analyzeProject(
          tmp.path,
          options: opts().copyWith(
            recursive: true,
            excludeProjects: {'proj'},
          ),
          client: client(),
        ),
        throwsA(isA<ProjectAnalysisException>()),
      );
    });

    test('shared lockfile findings are reported once', () async {
      final ws = await Directory.systemTemp.createTemp('pub_health_ws_');
      addTearDown(() => ws.delete(recursive: true));
      await createTempProject(
        parent: ws,
        pubspec: 'name: root\nworkspace:\n  - a\n  - b\n',
        lock: lockFile([lockEntry('trans', '1.0.0', dependency: 'transitive')]),
      );
      for (final n in ['a', 'b']) {
        await createTempProject(
          parent: ws,
          subdir: n,
          pubspec: 'name: $n\nresolution: workspace\n',
        );
      }
      final c = mockPubDevClient(
        packages: {
          'trans': packageJson(
            name: 'trans',
            latestVersion: '2.0.0',
            sdkConstraint: '>=3.0.0 <4.0.0',
          ),
        },
      );
      final report = await analyzeProject(
        ws.path,
        options: opts().copyWith(recursive: true),
        client: c,
      );
      final outdated = report.findings.where(
          (f) => f.ruleId == 'outdated_dependency' && f.package == 'trans');
      expect(outdated, hasLength(1));
    });

    test('no pubspec anywhere is an error', () async {
      final empty = await Directory.systemTemp.createTemp('pub_health_empty_');
      addTearDown(() => empty.delete(recursive: true));
      await expectLater(
        analyzeProject(
          empty.path,
          options: opts().copyWith(recursive: true),
          client: client(),
        ),
        throwsA(isA<ProjectAnalysisException>()),
      );
    });
  });

  test('offline mode skips uncached packages with a warning', () async {
    final report = await ProjectAnalyzer(
      options: opts().copyWith(
        offline: true,
        useCache: true,
        cacheDir: p.join(tmp.path, 'empty_cache'),
      ),
    ).analyze(dir.path);
    expect(report.warnings.join(), contains('Offline mode'));
    expect(report.warnings.join(), contains('alpha'));
    // Offline-only rules (overrides, unconstrained, misplaced) still work.
    expect(
      report.findings.map((f) => f.ruleId),
      contains('dependency_override'),
    );
  });
}
