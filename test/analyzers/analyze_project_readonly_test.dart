import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:pub_health/pub_health.dart';
import 'package:test/test.dart';

import '../support/mock_pub_dev_client.dart';

void main() {
  test('analyzeProject does not modify the target pubspec.yaml', () async {
    final temp = await Directory.systemTemp.createTemp('pub_health_ro_');
    addTearDown(() => temp.delete(recursive: true));

    final pubspecPath = p.join(temp.path, 'pubspec.yaml');
    const original = '''
name: readonly_fixture
environment:
  sdk: ^3.5.0
dependencies:
  path: ^1.9.0
''';
    await File(pubspecPath).writeAsString(original);
    await File(p.join(temp.path, 'pubspec.lock')).writeAsString('''
packages:
  path:
    dependency: "direct main"
    description:
      name: path
      url: "https://pub.dev"
    source: hosted
    version: "1.9.0"
sdks:
  dart: ">=3.5.0 <4.0.0"
''');
    await Directory(p.join(temp.path, 'lib')).create();
    await File(p.join(temp.path, 'lib', 'main.dart')).writeAsString(
      "import 'package:path/path.dart';\n",
    );

    final beforeBytes = await File(pubspecPath).readAsBytes();

    await analyzeProject(
      temp.path,
      options: PubHealthOptions(now: DateTime.utc(2026, 10, 20)),
      client: healthyFixtureClient(),
    );

    final afterBytes = await File(pubspecPath).readAsBytes();
    expect(afterBytes, beforeBytes);
    expect(await File(pubspecPath).readAsString(), original);
  });
}
