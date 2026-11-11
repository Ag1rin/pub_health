import '../models/dependency_kind.dart';
import '../models/health_finding.dart';
import '../models/severity.dart';
import 'rule.dart';

/// Flags dependencies pulled straight from git, which pub.dev cannot audit.
class GitDependencyRule extends Rule {
  /// Creates a git-dependency rule.
  const GitDependencyRule();

  @override
  String get id => 'git_dependency';

  @override
  String get name => 'Git dependency';

  @override
  List<HealthFinding> evaluate(RuleContext context) {
    final findings = <HealthFinding>[];
    for (final dep in context.dependencies) {
      if (dep.kind == DependencyKind.transitive) continue;
      if (dep.source != 'git') continue;
      if (context.options.exclude.contains(dep.name)) continue;

      findings.add(
        HealthFinding(
          ruleId: id,
          package: dep.name,
          severity: Severity.low,
          title: 'Dependency comes from git',
          detail: '${dep.name} is fetched from git'
              '${dep.sourceUrl == null ? '' : ' (${dep.sourceUrl})'}, so '
              'pub.dev cannot report discontinuation, retraction, or '
              'security status for it. It also blocks publishing to pub.dev.',
          recommendation:
              'Prefer a released pub.dev version, pin to an immutable commit '
              '(`ref:` with a SHA), and track the upstream release.',
          metadata: {
            'lockedVersion': dep.lockedVersion,
            'sourceUrl': dep.sourceUrl,
            'line': dep.declaredLine,
          },
        ),
      );
    }
    return findings;
  }
}
