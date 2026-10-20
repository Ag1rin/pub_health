import 'package:pub_health/src/models/dependency.dart';
import 'package:pub_health/src/models/dependency_kind.dart';
import 'package:pub_health/src/models/pub_dev_package_info.dart';
import 'package:pub_health/src/models/pub_health_options.dart';
import 'package:pub_health/src/rules/rule.dart';
import 'package:pub_health/src/rules/stale_package_rule.dart';
import 'package:test/test.dart';

import '../support/mock_pub_dev_client.dart';

void main() {
  final now = DateTime.utc(2026, 10, 20);

  test('flags stale packages', () {
    final findings = const StalePackageRule().evaluate(
      RuleContext(
        projectPath: '.',
        dependencies: const [
          Dependency(
            name: 'stale',
            kind: DependencyKind.direct,
            lockedVersion: '1.0.0',
          ),
        ],
        packageInfo: {
          'stale': info(
            name: 'stale',
            latestVersion: '1.0.0',
            latestPublished: now.subtract(const Duration(days: 700)),
            score: const PubDevScoreInfo(
              grantedPoints: 80,
              maxPoints: 160,
              likeCount: 5,
              downloadCount30Days: 10,
            ),
          ),
        },
        unusedPackages: const {},
        options: PubHealthOptions(now: now, staleAfterMonths: 18),
      ),
    );
    expect(findings, hasLength(1));
    expect(findings.single.ruleId, 'stale_package');
  });

  test('skips popular healthy packages', () {
    final findings = const StalePackageRule().evaluate(
      RuleContext(
        projectPath: '.',
        dependencies: const [
          Dependency(
            name: 'popular',
            kind: DependencyKind.direct,
            lockedVersion: '1.0.0',
          ),
        ],
        packageInfo: {
          'popular': info(
            name: 'popular',
            latestVersion: '1.0.0',
            latestPublished: now.subtract(const Duration(days: 700)),
            score: const PubDevScoreInfo(
              grantedPoints: 140,
              maxPoints: 160,
              likeCount: 5000,
              downloadCount30Days: 100000,
            ),
          ),
        },
        unusedPackages: const {},
        options: PubHealthOptions(now: now),
      ),
    );
    expect(findings, isEmpty);
  });
}
