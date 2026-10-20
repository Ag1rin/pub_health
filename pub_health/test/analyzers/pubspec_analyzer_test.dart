import 'package:pub_health/src/analyzers/pubspec_analyzer.dart';
import 'package:pub_health/src/models/dependency_kind.dart';
import 'package:pub_health/src/utils/yaml_utils.dart';
import 'package:test/test.dart';

void main() {
  final analyzer = PubspecAnalyzer();

  test('parses direct and dev dependencies', () {
    const yaml = '''
name: demo
environment:
  sdk: ^3.5.0
dependencies:
  http: ^1.2.0
  flutter:
    sdk: flutter
dev_dependencies:
  test: ^1.25.0
''';
    final data = analyzer.parse(yaml);
    expect(data.name, 'demo');
    expect(data.sdkConstraint, '^3.5.0');
    expect(data.directDependencies, hasLength(2));
    expect(
      data.directDependencies.map((d) => d.name),
      containsAll(['http', 'flutter']),
    );
    expect(
      data.directDependencies.firstWhere((d) => d.name == 'flutter').isSdk,
      isTrue,
    );
    expect(data.devDependencies.single.name, 'test');
    expect(data.devDependencies.single.kind, DependencyKind.dev);
  });

  test('throws on malformed YAML', () {
    expect(
      () => analyzer.parse('dependencies:\n  foo: [\n :'),
      throwsA(isA<YamlParseException>()),
    );
  });
}
