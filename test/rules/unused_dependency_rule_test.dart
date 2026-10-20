import 'package:pub_health/src/models/dependency.dart';
import 'package:pub_health/src/models/dependency_kind.dart';
import 'package:pub_health/src/models/pub_health_options.dart';
import 'package:pub_health/src/rules/rule.dart';
import 'package:pub_health/src/rules/unused_dependency_rule.dart';
import 'package:test/test.dart';

void main() {
  test('flags unused direct dependencies', () {
    final findings = const UnusedDependencyRule().evaluate(
      RuleContext(
        projectPath: '.',
        dependencies: const [
          Dependency(
            name: 'unused_pkg',
            kind: DependencyKind.direct,
            lockedVersion: '1.0.0',
          ),
        ],
        packageInfo: const {},
        unusedPackages: const {'unused_pkg'},
        options: const PubHealthOptions(),
      ),
    );
    expect(findings.single.ruleId, 'unused_dependency');
  });

  test('respects exclude list', () {
    final findings = const UnusedDependencyRule().evaluate(
      RuleContext(
        projectPath: '.',
        dependencies: const [
          Dependency(
            name: 'unused_pkg',
            kind: DependencyKind.direct,
            lockedVersion: '1.0.0',
          ),
        ],
        packageInfo: const {},
        unusedPackages: const {'unused_pkg'},
        options: const PubHealthOptions(exclude: {'unused_pkg'}),
      ),
    );
    expect(findings, isEmpty);
  });
}
