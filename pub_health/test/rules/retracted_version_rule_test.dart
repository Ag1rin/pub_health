import 'package:pub_health/src/models/dependency.dart';
import 'package:pub_health/src/models/dependency_kind.dart';
import 'package:pub_health/src/models/pub_dev_package_info.dart';
import 'package:pub_health/src/models/pub_health_options.dart';
import 'package:pub_health/src/models/severity.dart';
import 'package:pub_health/src/rules/retracted_version_rule.dart';
import 'package:pub_health/src/rules/rule.dart';
import 'package:test/test.dart';

import '../support/mock_pub_dev_client.dart';

void main() {
  test('flags retracted locked versions', () {
    final findings = const RetractedVersionRule().evaluate(
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
            latestVersion: '1.1.0',
            versions: const [
              PubDevVersionInfo(version: '1.0.0', retracted: true),
              PubDevVersionInfo(version: '1.1.0'),
            ],
          ),
        },
        unusedPackages: const {},
        options: const PubHealthOptions(),
      ),
    );
    expect(findings.single.severity, Severity.high);
    expect(findings.single.ruleId, 'retracted_version');
  });
}
