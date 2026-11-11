import '../models/health_finding.dart';
import '../models/severity.dart';
import 'rule.dart';

/// Checks package licenses reported by pub.dev against a policy.
///
/// pub.dev exposes licenses as score tags such as `license:mit` (lowercase
/// SPDX identifiers). `license:osi-approved` and `license:fsf-libre` are
/// classification tags, not licenses, and are ignored here.
///
/// Without configuration only packages with a missing or `unknown` license
/// are flagged. Configure `licenses.allow` / `licenses.deny` in
/// `pub_health.yaml` for a real policy.
class LicenseRule extends Rule {
  /// Creates a license rule.
  const LicenseRule();

  @override
  String get id => 'license_risk';

  @override
  String get name => 'License risk';

  static const String _prefix = 'license:';
  static const Set<String> _classificationTags = {
    'osi-approved',
    'fsf-libre',
  };

  /// Extracts SPDX-style license ids from pub.dev [tags].
  static Set<String> licensesFromTags(Iterable<String> tags) {
    return {
      for (final tag in tags)
        if (tag.startsWith(_prefix) &&
            !_classificationTags.contains(tag.substring(_prefix.length)))
          tag.substring(_prefix.length),
    };
  }

  @override
  List<HealthFinding> evaluate(RuleContext context) {
    final findings = <HealthFinding>[];
    final allowed = context.options.allowedLicenses;
    final denied = context.options.deniedLicenses;

    for (final dep in context.hostedDependencies) {
      final score = context.infoFor(dep.name)?.score;
      // No tag data at all means we cannot judge — never guess.
      if (score == null || score.tags.isEmpty) continue;

      final licenses = licensesFromTags(score.tags);
      final isUnknown = licenses.isEmpty || licenses.contains('unknown');
      final shown = licenses.isEmpty ? 'none reported' : licenses.join(', ');

      final blocked = licenses.intersection(denied);
      if (blocked.isNotEmpty) {
        findings.add(
          _finding(
            dep.name,
            Severity.high,
            'Uses a denied license (${blocked.join(', ')}).',
            'Replace ${dep.name} or get legal sign-off, then add an '
                '`ignore` entry with a reason.',
            licenses,
            dep.lockedVersion,
          ),
        );
        continue;
      }

      if (isUnknown) {
        findings.add(
          _finding(
            dep.name,
            Severity.medium,
            'pub.dev reports no recognised license ($shown).',
            'Check the package repository for a license before shipping '
                'it; an unlicensed package may not be legally usable.',
            licenses,
            dep.lockedVersion,
          ),
        );
        continue;
      }

      if (allowed.isNotEmpty) {
        final notAllowed = licenses.difference(allowed);
        if (notAllowed.isNotEmpty) {
          findings.add(
            _finding(
              dep.name,
              Severity.high,
              'License ${notAllowed.join(', ')} is not in the allowed list.',
              'Replace ${dep.name} or extend `licenses.allow` after review.',
              licenses,
              dep.lockedVersion,
            ),
          );
        }
      }
    }
    return findings;
  }

  HealthFinding _finding(
    String package,
    Severity severity,
    String detail,
    String recommendation,
    Set<String> licenses,
    String? lockedVersion,
  ) {
    return HealthFinding(
      ruleId: id,
      package: package,
      severity: severity,
      title: 'License needs review',
      detail: detail,
      recommendation: recommendation,
      metadata: {
        'lockedVersion': lockedVersion,
        'licenses': licenses.toList()..sort(),
      },
    );
  }
}
