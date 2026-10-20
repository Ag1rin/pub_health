import 'package:pub_health/src/models/dependency.dart';
import 'package:pub_health/src/models/dependency_kind.dart';
import 'package:pub_health/src/models/pub_health_options.dart';
import 'package:pub_health/src/models/severity.dart';
import 'package:pub_health/src/rules/rule.dart';
import 'package:pub_health/src/rules/sdk_constraint_rule.dart';
import 'package:test/test.dart';

import '../support/mock_pub_dev_client.dart';

void main() {
  test('flags incompatible package SDK constraints', () {
    final findings = const SdkConstraintRule().evaluate(
      RuleContext(
        projectPath: '.',
        dependencies: const [
          Dependency(
            name: 'old_sdk',
            kind: DependencyKind.direct,
            lockedVersion: '1.0.0',
          ),
        ],
        packageInfo: {
          'old_sdk': info(
            name: 'old_sdk',
            latestVersion: '1.0.0',
            sdkConstraint: '>=2.12.0 <3.0.0',
          ),
        },
        unusedPackages: const {},
        options: const PubHealthOptions(),
        projectSdkConstraint: '>=3.5.0 <4.0.0',
      ),
    );
    expect(findings.single.severity, Severity.high);
    expect(findings.single.ruleId, 'sdk_constraint_risk');
  });

  test('allows compatible SDK constraints', () {
    final findings = const SdkConstraintRule().evaluate(
      RuleContext(
        projectPath: '.',
        dependencies: const [
          Dependency(
            name: 'ok',
            kind: DependencyKind.direct,
            lockedVersion: '1.0.0',
          ),
        ],
        packageInfo: {
          'ok': info(
            name: 'ok',
            latestVersion: '1.0.0',
            sdkConstraint: '>=3.0.0 <4.0.0',
          ),
        },
        unusedPackages: const {},
        options: const PubHealthOptions(),
        projectSdkConstraint: '^3.5.0',
      ),
    );
    expect(findings, isEmpty);
  });
}
