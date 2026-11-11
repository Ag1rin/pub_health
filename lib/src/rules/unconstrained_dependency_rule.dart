import 'package:pub_semver/pub_semver.dart';

import '../models/dependency_kind.dart';
import '../models/health_finding.dart';
import '../models/severity.dart';
import 'rule.dart';

/// Flags hosted dependencies whose version constraint is missing or too open.
class UnconstrainedDependencyRule extends Rule {
  /// Creates an unconstrained-dependency rule.
  const UnconstrainedDependencyRule();

  @override
  String get id => 'unconstrained_dependency';

  @override
  String get name => 'Unconstrained dependency';

  @override
  List<HealthFinding> evaluate(RuleContext context) {
    final findings = <HealthFinding>[];
    for (final dep in context.dependencies) {
      if (dep.kind == DependencyKind.transitive) continue;
      if (dep.isSdk || dep.source != 'hosted') continue;
      if (context.options.exclude.contains(dep.name)) continue;

      final isRuntime = dep.kind == DependencyKind.direct;
      final raw = dep.constraint?.trim();

      if (raw == null || raw.isEmpty || raw == 'any') {
        findings.add(
          _finding(
            dep.name,
            severity: isRuntime ? Severity.medium : Severity.low,
            detail: raw == 'any'
                ? '${dep.name} is declared as `any`, so any version — '
                    'including breaking releases — may be resolved.'
                : '${dep.name} has no version constraint, so any version — '
                    'including breaking releases — may be resolved.',
            recommendation: 'Use a caret constraint, e.g. '
                '`${dep.name}: ^${dep.lockedVersion ?? 'x.y.z'}`.',
            dep: dep.lockedVersion,
            constraint: raw,
            line: dep.declaredLine,
          ),
        );
        continue;
      }

      // Open upper bound (e.g. `>=1.2.0`) only matters for runtime deps.
      if (!isRuntime) continue;
      final parsed = _tryParse(raw);
      if (parsed is VersionRange && parsed.max == null && parsed.min != null) {
        findings.add(
          _finding(
            dep.name,
            severity: Severity.low,
            detail: 'The constraint `$raw` for ${dep.name} has no upper '
                'bound, so future major releases are allowed automatically.',
            recommendation: 'Add an upper bound or switch to a caret '
                'constraint (`^${parsed.min}`).',
            dep: dep.lockedVersion,
            constraint: raw,
            line: dep.declaredLine,
          ),
        );
      }
    }
    return findings;
  }

  VersionConstraint? _tryParse(String raw) {
    try {
      return VersionConstraint.parse(raw);
    } on FormatException {
      return null;
    }
  }

  HealthFinding _finding(
    String package, {
    required Severity severity,
    required String detail,
    required String recommendation,
    String? dep,
    String? constraint,
    int? line,
  }) {
    return HealthFinding(
      ruleId: id,
      package: package,
      severity: severity,
      title: 'Version constraint is too open',
      detail: detail,
      recommendation: recommendation,
      metadata: {
        'lockedVersion': dep,
        'constraint': constraint,
        'line': line,
      },
    );
  }
}
