import 'package:pub_health/src/models/dependency.dart';
import 'package:pub_health/src/models/dependency_kind.dart';
import 'package:pub_health/src/models/pub_health_options.dart';
import 'package:pub_health/src/rules/discontinued_rule.dart';
import 'package:pub_health/src/rules/outdated_rule.dart';
import 'package:pub_health/src/rules/rule.dart';
import 'package:pub_health/src/rules/rule_engine.dart';
import 'package:test/test.dart';

import '../support/mock_pub_dev_client.dart';

void main() {
  test('skips disabled rules', () {
    final engine = RuleEngine(
      rules: const [OutdatedRule(), DiscontinuedRule()],
    );
    final findings = engine.evaluate(
      RuleContext(
        projectPath: '.',
        dependencies: const [
          Dependency(
            name: 'pkg',
            kind: DependencyKind.direct,
            lockedVersion: '1.0.0',
          ),
        ],
        packageInfo: {
          'pkg': info(
            name: 'pkg',
            latestVersion: '2.0.0',
            discontinued: true,
          ),
        },
        unusedPackages: const {},
        options: const PubHealthOptions(
          disabledRules: {'outdated_dependency'},
        ),
      ),
    );

    expect(findings.map((f) => f.ruleId), ['discontinued_package']);
  });

  test('deduplicates identical findings', () {
    final engine = RuleEngine(
      rules: const [DiscontinuedRule(), DiscontinuedRule()],
    );
    final findings = engine.evaluate(
      RuleContext(
        projectPath: '.',
        dependencies: const [
          Dependency(
            name: 'pkg',
            kind: DependencyKind.direct,
            lockedVersion: '1.0.0',
          ),
        ],
        packageInfo: {
          'pkg': info(
            name: 'pkg',
            latestVersion: '1.0.0',
            discontinued: true,
          ),
        },
        unusedPackages: const {},
        options: const PubHealthOptions(),
      ),
    );

    expect(findings, hasLength(1));
  });
}
