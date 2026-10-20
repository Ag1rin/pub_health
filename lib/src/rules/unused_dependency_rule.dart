import '../models/dependency_kind.dart';
import '../models/health_finding.dart';
import '../models/severity.dart';
import 'rule.dart';

/// Detects direct runtime dependencies with no matching import.
class UnusedDependencyRule extends Rule {
  /// Creates an unused-dependency rule.
  const UnusedDependencyRule();

  @override
  String get id => 'unused_dependency';

  @override
  String get name => 'Unused dependency';

  @override
  List<HealthFinding> evaluate(RuleContext context) {
    final findings = <HealthFinding>[];
    final directNames = context.dependencies
        .where((d) => d.kind == DependencyKind.direct)
        .map((d) => d.name)
        .toSet();

    for (final name in context.unusedPackages) {
      if (context.options.exclude.contains(name)) continue;
      if (!directNames.contains(name)) continue;

      final dep = context.dependencies.firstWhere((d) => d.name == name);
      findings.add(
        HealthFinding(
          ruleId: id,
          package: name,
          severity: Severity.medium,
          title: 'Unused direct dependency',
          detail:
              'Direct dependency has no detected import in lib/, bin/, or test/.',
          recommendation:
              'Remove the dependency if it is unused, or keep it if it is '
              'required indirectly (e.g. code generation).',
          metadata: {
            'lockedVersion': dep.lockedVersion,
            'constraint': dep.constraint,
          },
        ),
      );
    }
    return findings;
  }
}
