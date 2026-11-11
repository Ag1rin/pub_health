import '../models/dependency_kind.dart';
import '../models/health_finding.dart';
import '../models/severity.dart';
import 'rule.dart';

/// Detects dependencies declared in the wrong pubspec section.
///
/// * A `dev_dependencies` package imported from `lib/` or `bin/` will be
///   missing for consumers of a published package.
/// * A well-known tooling package listed under `dependencies` (and never
///   imported from shipped code) bloats the dependency graph of consumers.
class MisplacedDependencyRule extends Rule {
  /// Creates a misplaced-dependency rule.
  const MisplacedDependencyRule();

  @override
  String get id => 'misplaced_dependency';

  @override
  String get name => 'Misplaced dependency';

  /// Packages that are only ever needed at development / build time.
  static const Set<String> devOnlyPackages = {
    'test',
    'flutter_test',
    'integration_test',
    'mocktail',
    'mockito',
    'build_runner',
    'build_test',
    'lints',
    'flutter_lints',
    'very_good_analysis',
    'pedantic',
    'json_serializable',
    'freezed',
    'source_gen',
    'flutter_launcher_icons',
    'flutter_native_splash',
    'custom_lint',
  };

  @override
  List<HealthFinding> evaluate(RuleContext context) {
    final findings = <HealthFinding>[];
    for (final dep in context.dependencies) {
      if (dep.isSdk && dep.name != 'integration_test') continue;
      if (context.options.exclude.contains(dep.name)) continue;

      if (dep.kind == DependencyKind.dev &&
          !dep.isSdk &&
          context.productionImports.contains(dep.name)) {
        findings.add(
          HealthFinding(
            ruleId: id,
            package: dep.name,
            severity: Severity.medium,
            title: 'Dev dependency used in shipped code',
            detail: '${dep.name} is under `dev_dependencies` but is imported '
                'from lib/ or bin/. Anyone depending on this package will '
                'fail to resolve the import.',
            recommendation: 'Move ${dep.name} to `dependencies`.',
            metadata: {
              'lockedVersion': dep.lockedVersion,
              'direction': 'dev_to_runtime',
              'line': dep.declaredLine,
              'suggestedCommand':
                  '${context.pubTool} pub remove --dev ${dep.name} && '
                      '${context.pubTool} pub add ${dep.name}',
            },
          ),
        );
      }

      if (dep.kind == DependencyKind.direct &&
          devOnlyPackages.contains(dep.name) &&
          !context.productionImports.contains(dep.name)) {
        findings.add(
          HealthFinding(
            ruleId: id,
            package: dep.name,
            severity: Severity.low,
            title: 'Tooling package under dependencies',
            detail: '${dep.name} is normally a development-only package '
                'and is not imported from lib/ or bin/.',
            recommendation: 'Move ${dep.name} to `dev_dependencies`.',
            metadata: {
              'lockedVersion': dep.lockedVersion,
              'direction': 'runtime_to_dev',
              'line': dep.declaredLine,
              'suggestedCommand':
                  '${context.pubTool} pub remove ${dep.name} && '
                      '${context.pubTool} pub add --dev ${dep.name}',
            },
          ),
        );
      }
    }
    return findings;
  }
}
