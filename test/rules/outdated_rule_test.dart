import 'package:pub_health/src/models/dependency.dart';
import 'package:pub_health/src/models/dependency_kind.dart';
import 'package:pub_health/src/models/pub_health_options.dart';
import 'package:pub_health/src/rules/outdated_rule.dart';
import 'package:pub_health/src/rules/rule.dart';
import 'package:test/test.dart';

import '../support/mock_pub_dev_client.dart';

void main() {
  test('flags outdated locked versions', () {
    const rule = OutdatedRule();
    final findings = rule.evaluate(
      RuleContext(
        projectPath: '.',
        dependencies: const [
          Dependency(
            name: 'http',
            kind: DependencyKind.direct,
            lockedVersion: '0.13.0',
          ),
        ],
        packageInfo: {
          'http': info(name: 'http', latestVersion: '1.2.0'),
        },
        unusedPackages: const {},
        options: const PubHealthOptions(),
      ),
    );
    expect(findings, hasLength(1));
    expect(findings.single.ruleId, 'outdated_dependency');
    expect(findings.single.metadata['upgradeType'], 'major');
  });

  test('ignores up-to-date packages', () {
    const rule = OutdatedRule();
    final findings = rule.evaluate(
      RuleContext(
        projectPath: '.',
        dependencies: const [
          Dependency(
            name: 'path',
            kind: DependencyKind.direct,
            lockedVersion: '1.9.0',
          ),
        ],
        packageInfo: {
          'path': info(name: 'path', latestVersion: '1.9.0'),
        },
        unusedPackages: const {},
        options: const PubHealthOptions(),
      ),
    );
    expect(findings, isEmpty);
  });
}
