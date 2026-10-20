import 'package:pub_health/src/analyzers/lockfile_analyzer.dart';
import 'package:pub_health/src/analyzers/pubspec_analyzer.dart';
import 'package:pub_health/src/models/dependency_kind.dart';
import 'package:test/test.dart';

void main() {
  final analyzer = LockfileAnalyzer();

  test('parses locked packages', () {
    const lock = '''
packages:
  http:
    dependency: "direct main"
    description:
      name: http
      url: "https://pub.dev"
    source: hosted
    version: "1.2.2"
  matcher:
    dependency: transitive
    description:
      name: matcher
      url: "https://pub.dev"
    source: hosted
    version: "0.12.16"
sdks:
  dart: ">=3.5.0 <4.0.0"
''';
    final data = analyzer.parse(lock);
    expect(data.missing, isFalse);
    expect(data.packages['http']!.version, '1.2.2');
    expect(data.packages['matcher']!.dependency, 'transitive');
  });

  test('merges pubspec and lockfile', () {
    final pubspec = PubspecAnalyzer().parse('''
name: demo
environment:
  sdk: ^3.5.0
dependencies:
  http: ^1.2.0
''');
    final lock = analyzer.parse('''
packages:
  http:
    dependency: "direct main"
    description:
      name: http
      url: "https://pub.dev"
    source: hosted
    version: "1.2.2"
  async:
    dependency: transitive
    description:
      name: async
      url: "https://pub.dev"
    source: hosted
    version: "2.11.0"
''');
    final merged = analyzer.mergeWithPubspec(pubspec, lock);
    expect(merged.where((d) => d.name == 'http').single.lockedVersion, '1.2.2');
    expect(
      merged.where((d) => d.name == 'async').single.kind,
      DependencyKind.transitive,
    );
  });

  test('missing lockfile returns empty missing data', () async {
    final data = await analyzer.analyze('test/fixtures/malformed_project');
    expect(data.missing, isTrue);
    expect(data.packages, isEmpty);
  });
}
