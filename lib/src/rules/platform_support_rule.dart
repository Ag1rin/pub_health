import '../models/dependency_kind.dart';
import '../models/health_finding.dart';
import '../models/severity.dart';
import 'rule.dart';

/// Verifies that direct dependencies support the platforms the project
/// targets (and, optionally, WebAssembly).
///
/// Uses pub.dev score tags (`platform:android`, `platform:web`,
/// `is:wasm-ready`, …). The rule is inert unless `platforms:` or `wasm: true`
/// is configured, and it never judges a package that reports no platform
/// tags at all.
class PlatformSupportRule extends Rule {
  /// Creates a platform-support rule.
  const PlatformSupportRule();

  @override
  String get id => 'platform_support';

  @override
  String get name => 'Platform support';

  @override
  List<HealthFinding> evaluate(RuleContext context) {
    final required = context.options.platforms;
    final wantWasm = context.options.requireWasm;
    if (required.isEmpty && !wantWasm) return const [];

    final findings = <HealthFinding>[];
    for (final dep in context.hostedDependencies) {
      if (dep.kind != DependencyKind.direct) continue;
      final score = context.infoFor(dep.name)?.score;
      if (score == null || score.tags.isEmpty) continue;

      final supported = {
        for (final tag in score.tags)
          if (tag.startsWith('platform:')) tag.substring('platform:'.length),
      };
      final hasPlatformData = supported.isNotEmpty;
      final problems = <String>[];

      var missing = <String>[];
      if (required.isNotEmpty && hasPlatformData) {
        missing = required.difference(supported).toList()..sort();
        if (missing.isNotEmpty) {
          problems.add('does not declare support for ${missing.join(', ')}');
        }
      }

      var notWasm = false;
      if (wantWasm && hasPlatformData) {
        notWasm = !score.tags.contains('is:wasm-ready');
        if (notWasm) problems.add('is not marked WebAssembly-ready');
      }

      if (problems.isEmpty) continue;
      findings.add(
        HealthFinding(
          ruleId: id,
          package: dep.name,
          // A missing target platform can break builds; wasm alone is advisory.
          severity: missing.isNotEmpty ? Severity.medium : Severity.low,
          title: 'Platform support gap',
          detail: '${dep.name} ${problems.join(' and ')} on pub.dev.',
          recommendation:
              'Check the package page for platform notes, or choose an '
              'alternative that supports every platform you ship to.',
          metadata: {
            'lockedVersion': dep.lockedVersion,
            'missingPlatforms': missing,
            'wasmReady': !notWasm,
            'supportedPlatforms': supported.toList()..sort(),
            'line': dep.declaredLine,
          },
        ),
      );
    }
    return findings;
  }
}
