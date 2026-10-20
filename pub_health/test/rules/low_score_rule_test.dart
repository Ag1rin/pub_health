import 'package:pub_health/src/models/dependency.dart';
import 'package:pub_health/src/models/dependency_kind.dart';
import 'package:pub_health/src/models/pub_dev_package_info.dart';
import 'package:pub_health/src/models/pub_health_options.dart';
import 'package:pub_health/src/models/severity.dart';
import 'package:pub_health/src/rules/low_score_rule.dart';
import 'package:pub_health/src/rules/rule.dart';
import 'package:test/test.dart';

import '../support/mock_pub_dev_client.dart';

void main() {
  test('flags low pub points', () {
    final findings = const LowScoreRule().evaluate(
      RuleContext(
        projectPath: '.',
        dependencies: const [
          Dependency(
            name: 'weak',
            kind: DependencyKind.direct,
            lockedVersion: '1.0.0',
          ),
        ],
        packageInfo: {
          'weak': info(
            name: 'weak',
            latestVersion: '1.0.0',
            score: const PubDevScoreInfo(
              grantedPoints: 20,
              maxPoints: 160,
            ),
          ),
        },
        unusedPackages: const {},
        options: const PubHealthOptions(),
      ),
    );
    expect(findings.single.severity, Severity.low);
    expect(findings.single.ruleId, 'low_package_score');
  });
}
