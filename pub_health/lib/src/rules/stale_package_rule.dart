import '../models/health_finding.dart';
import '../models/pub_dev_package_info.dart';
import '../models/severity.dart';
import 'rule.dart';

/// Detects packages whose latest release is older than a threshold.
class StalePackageRule extends Rule {
  /// Creates a stale-package rule.
  const StalePackageRule();

  @override
  String get id => 'stale_package';

  @override
  String get name => 'Stale package';

  /// Minimum likes to treat a package as widely used.
  static const int popularLikeThreshold = 500;

  /// Minimum 30-day downloads to treat a package as widely used.
  static const int popularDownloadThreshold = 50000;

  /// Minimum pub points ratio to treat a package as high quality.
  static const double healthyScoreRatio = 0.8;

  @override
  List<HealthFinding> evaluate(RuleContext context) {
    final findings = <HealthFinding>[];
    final now = context.options.now?.toUtc() ?? DateTime.now().toUtc();
    final thresholdMonths = context.options.staleAfterMonths;

    for (final dep in context.hostedDependencies) {
      final info = context.infoFor(dep.name);
      if (info == null || info.notFound) continue;
      final published = info.latestPublished;
      if (published == null) continue;

      final age = now.difference(published);
      final ageMonths = (age.inDays / 30.44).floor();
      if (ageMonths < thresholdMonths) continue;

      // Reduce false positives for popular, high-quality packages.
      if (_isWidelyUsedHealthy(info)) continue;

      findings.add(
        HealthFinding(
          ruleId: id,
          package: dep.name,
          severity: Severity.medium,
          title: 'Package appears stale',
          detail: 'Last release: $ageMonths months ago.',
          recommendation:
              'Confirm the package is still maintained or evaluate alternatives.',
          metadata: {
            'lockedVersion': dep.lockedVersion,
            'latestVersion': info.latestVersion,
            'lastPublished': published.toIso8601String(),
            'ageMonths': ageMonths,
            'staleAfterMonths': thresholdMonths,
          },
        ),
      );
    }
    return findings;
  }

  bool _isWidelyUsedHealthy(PubDevPackageInfo info) {
    final score = info.score;
    if (score == null) return false;
    final popular = score.likeCount >= popularLikeThreshold ||
        score.downloadCount30Days >= popularDownloadThreshold;
    final healthy = score.ratio >= healthyScoreRatio;
    return popular && healthy;
  }
}
