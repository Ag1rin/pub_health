import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:pub_health/src/analyzers/lockfile_analyzer.dart';
import 'package:pub_health/src/analyzers/pubspec_analyzer.dart';
import 'package:pub_health/src/analyzers/unused_dependency_analyzer.dart';
import 'package:pub_health/src/models/dependency_kind.dart';
import 'package:test/test.dart';

import '../support/temp_project.dart';

void main() {
  final analyzer = PubspecAnalyzer();

  test('records declaration lines (1-based) and git/path sources', () {
    final data = analyzer.parse('''
name: demo
environment:
  sdk: ^3.5.0
dependencies:
  http: ^1.0.0
  gitpkg:
    git:
      url: https://example.com/g.git
      ref: abc123
  shortgit:
    git: https://example.com/s.git
  localpkg:
    path: ../local
  anypkg:
dev_dependencies:
  test: ^1.0.0
''');
    final byName = {for (final d in data.allDeclared) d.name: d};
    expect(byName['http']!.declaredLine, 5);
    expect(byName['gitpkg']!.source, 'git');
    expect(byName['gitpkg']!.sourceUrl, 'https://example.com/g.git');
    expect(byName['shortgit']!.sourceUrl, 'https://example.com/s.git');
    expect(byName['localpkg']!.source, 'path');
    expect(byName['localpkg']!.sourceUrl, '../local');
    expect(byName['anypkg']!.constraint, isNull);
    expect(byName['test']!.kind, DependencyKind.dev);
  });

  test('parses dependency_overrides with lines', () {
    final data = analyzer.parse('''
name: demo
dependencies:
  a: ^1.0.0
dependency_overrides:
  a: 1.2.3
  b:
    path: ../b
  c:
    git: https://example.com/c.git
''');
    expect(data.overrides.map((o) => o.name), ['a', 'b', 'c']);
    expect(data.overrides[0].source, 'hosted');
    expect(data.overrides[0].constraint, '1.2.3');
    expect(data.overrides[0].declaredLine, 5);
    expect(data.overrides[1].source, 'path');
    expect(data.overrides[2].sourceUrl, 'https://example.com/c.git');
  });

  test('detects Flutter projects and workspace settings', () {
    final flutter = analyzer.parse('''
name: app
dependencies:
  flutter:
    sdk: flutter
''');
    expect(flutter.isFlutter, isTrue);

    final plain = analyzer.parse('name: lib\ndependencies:\n  http: ^1.0.0\n');
    expect(plain.isFlutter, isFalse);

    final root = analyzer.parse('''
name: root
workspace:
  - packages/a
  - packages/b
''');
    expect(root.workspaceMembers, ['packages/a', 'packages/b']);
    expect(
      analyzer.parse('name: a\nresolution: workspace\n').resolvesWithWorkspace,
      isTrue,
    );
  });

  group('lockfile workspace resolution', () {
    late Directory root;
    tearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });

    test('member without a lockfile uses the workspace root lockfile',
        () async {
      root = await createTempProject(
        pubspec: 'name: root\nworkspace:\n  - pkgs/a\n',
        lock: lockFile([lockEntry('http', '1.2.0')]),
      );
      final member = await createTempProject(
        parent: root,
        subdir: 'pkgs/a',
        pubspec: 'name: a\nresolution: workspace\n',
      );

      final data = await LockfileAnalyzer().analyze(member.path);
      expect(data.missing, isFalse);
      expect(data.packages.keys, ['http']);
      expect(data.workspaceRoot, p.normalize(root.path));
    });

    test('ancestor without a workspace key is not used', () async {
      root = await createTempProject(
        pubspec: 'name: root\n',
        lock: lockFile([lockEntry('http', '1.2.0')]),
      );
      final child = await createTempProject(
        parent: root,
        subdir: 'child',
        pubspec: 'name: child\n',
      );
      final data = await LockfileAnalyzer().analyze(child.path);
      expect(data.missing, isTrue);
    });
  });

  group('import usage', () {
    test('separates shipped code from tests', () async {
      final dir = await createTempProject(
        pubspec: 'name: demo\n',
        files: {
          'lib/a.dart': "import 'package:http/http.dart';\n",
          'bin/m.dart': "export 'package:path/path.dart';\n",
          'test/t_test.dart': "import 'package:test/test.dart';\n",
        },
      );
      addTearDown(() => dir.delete(recursive: true));

      final usage = await UnusedDependencyAnalyzer().collectUsage(dir.path);
      expect(usage.production, {'http', 'path'});
      expect(usage.nonProduction, {'test'});
      expect(usage.all, {'http', 'path', 'test'});
    });
  });
}
