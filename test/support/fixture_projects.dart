import 'dart:io';

import 'package:path/path.dart' as p;

/// Materializes fixture Dart sources that cannot ship as `.dart` files
/// (fake package imports would fail `dart pub publish` validation).
Future<Directory> materializeRiskySources(String fixtureRoot) async {
  final libDir = Directory(p.join(fixtureRoot, 'lib'));
  await libDir.create(recursive: true);
  final template = File(p.join(fixtureRoot, 'lib', 'imports.dart.txt'));
  final target = File(p.join(fixtureRoot, 'lib', 'main.dart'));
  await target.writeAsString(await template.readAsString());
  return libDir;
}

/// Removes generated fixture sources.
Future<void> cleanupRiskySources(String fixtureRoot) async {
  final target = File(p.join(fixtureRoot, 'lib', 'main.dart'));
  if (await target.exists()) {
    await target.delete();
  }
}
