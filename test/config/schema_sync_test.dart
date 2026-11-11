import 'dart:convert';
import 'dart:io';

import 'package:pub_health/src/cli/init_template.dart';
import 'package:pub_health/src/config/pub_health_config.dart';
import 'package:pub_health/src/rules/rule_engine.dart';
import 'package:test/test.dart';

void main() {
  final schema =
      jsonDecode(File('doc/pub_health.schema.json').readAsStringSync())
          as Map<String, dynamic>;

  test('schema properties match the keys the parser understands', () {
    final keys = (schema['properties'] as Map).keys.toSet();
    expect(keys, PubHealthConfig.knownKeys);
  });

  test('schema rule enum matches the built-in rules', () {
    final ids =
        ((schema['definitions'] as Map)['ruleId'] as Map)['enum'] as List;
    expect(ids.toSet(), RuleEngine.defaultRuleIds.toSet());
  });

  test('init template parses and uses only known keys', () {
    final config = PubHealthConfig.parse(initConfigTemplate);
    expect(config.unknownKeys, isEmpty);
  });

  test('unknown keys are reported', () {
    final config = PubHealthConfig.parse('fail_on: low\nfail-on: high\n');
    expect(config.unknownKeys, ['fail_on']);
    expect(config.failOn?.name, 'high');
  });
}
