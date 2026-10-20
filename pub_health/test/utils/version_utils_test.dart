import 'package:pub_health/src/utils/version_utils.dart';
import 'package:test/test.dart';

void main() {
  test('detects outdated versions and bump kinds', () {
    expect(VersionUtils.isOutdated('1.0.0', '1.0.1'), isTrue);
    expect(VersionUtils.isOutdated('1.0.0', '1.0.0'), isFalse);
    expect(VersionUtils.classifyBump('1.0.0', '2.0.0'), VersionBump.major);
    expect(VersionUtils.classifyBump('1.0.0', '1.1.0'), VersionBump.minor);
    expect(VersionUtils.classifyBump('1.0.0', '1.0.1'), VersionBump.patch);
  });

  test('checks SDK constraints', () {
    expect(VersionUtils.allowsSdk('>=3.0.0 <4.0.0', '3.5.0'), isTrue);
    expect(VersionUtils.allowsSdk('>=2.12.0 <3.0.0', '3.5.0'), isFalse);
    expect(VersionUtils.minimumSdkFromConstraint('>=3.5.0 <4.0.0'), '3.5.0');
  });
}
