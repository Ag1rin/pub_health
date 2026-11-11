import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:pub_health/src/utils/file_utils.dart';
import 'package:test/test.dart';

void main() {
  test('absolute() normalizes "." instead of appending "/."', () {
    expect(FileUtils.absolute('.'), Directory.current.path);
    expect(FileUtils.absolute('.'), isNot(endsWith('.')));
  });

  test('absolute() collapses .. and redundant segments', () {
    expect(
      FileUtils.absolute('lib/../lib/./src'),
      p.join(Directory.current.path, 'lib', 'src'),
    );
  });

  test('absolute() leaves absolute paths intact', () {
    final root = p.rootPrefix(Directory.current.path);
    expect(FileUtils.absolute('${root}tmp/x'), p.join(root, 'tmp', 'x'));
  });
}
