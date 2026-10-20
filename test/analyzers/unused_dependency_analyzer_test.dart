import 'package:pub_health/src/analyzers/unused_dependency_analyzer.dart';
import 'package:pub_health/src/models/dependency.dart';
import 'package:pub_health/src/models/dependency_kind.dart';
import 'package:test/test.dart';

void main() {
  final analyzer = UnusedDependencyAnalyzer();

  test('detects unused direct dependency in risky fixture', () async {
    final deps = [
      const Dependency(name: 'outdated_pkg', kind: DependencyKind.direct),
      const Dependency(name: 'unused_pkg', kind: DependencyKind.direct),
      const Dependency(name: 'test', kind: DependencyKind.dev),
    ];
    final unused = await analyzer.findUnused(
      projectPath: 'test/fixtures/risky_project',
      dependencies: deps,
    );
    expect(unused, contains('unused_pkg'));
    expect(unused, isNot(contains('outdated_pkg')));
  });

  test('allow-lists known tooling packages', () async {
    final deps = [
      const Dependency(name: 'build_runner', kind: DependencyKind.direct),
    ];
    final unused = await analyzer.findUnused(
      projectPath: 'test/fixtures/healthy_project',
      dependencies: deps,
    );
    expect(unused, isEmpty);
  });
}
