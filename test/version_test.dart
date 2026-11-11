import 'dart:io';

import 'package:pub_health/src/version.dart';
import 'package:test/test.dart';

void main() {
  test('version constant matches pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match =
        RegExp(r'^version:\s*(\S+)', multiLine: true).firstMatch(pubspec);
    expect(match, isNotNull);
    expect(match!.group(1), pubHealthVersion);
  });

  test('CHANGELOG documents the current version', () {
    final changelog = File('CHANGELOG.md').readAsStringSync();
    expect(changelog, contains('## $pubHealthVersion'));
  });
}
