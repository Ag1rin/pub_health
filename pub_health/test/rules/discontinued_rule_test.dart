import 'package:pub_health/src/models/dependency.dart';
import 'package:pub_health/src/models/dependency_kind.dart';
import 'package:pub_health/src/models/pub_health_options.dart';
import 'package:pub_health/src/models/severity.dart';
import 'package:pub_health/src/rules/discontinued_rule.dart';
import 'package:pub_health/src/rules/rule.dart';
import 'package:test/test.dart';

import '../support/mock_pub_dev_client.dart';

void main() {
  test('flags discontinued packages as critical', () {
    final findings = const DiscontinuedRule().evaluate(
      RuleContext(
        projectPath: '.',
        dependencies: const [
          Dependency(
            name: 'old_pkg',
            kind: DependencyKind.direct,
            lockedVersion: '1.0.0',
          ),
        ],
        packageInfo: {
          'old_pkg': info(
            name: 'old_pkg',
            latestVersion: '1.0.0',
            discontinued: true,
          ),
        },
        unusedPackages: const {},
        options: const PubHealthOptions(),
      ),
    );
    expect(findings.single.severity, Severity.critical);
    expect(findings.single.ruleId, 'discontinued_package');
  });
}
