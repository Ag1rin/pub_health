import 'dart:io';

import 'package:pub_health/src/cli/command_runner.dart';

Future<void> main(List<String> arguments) async {
  final runner = PubHealthCommandRunner();
  final code = await runner.run(arguments);
  exit(code);
}
