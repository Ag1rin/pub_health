import 'package:pub_semver/pub_semver.dart';

/// Kind of version bump between two versions.
enum VersionBump {
  /// Same version.
  none,

  /// Patch-level difference.
  patch,

  /// Minor-level difference.
  minor,

  /// Major-level difference.
  major,
}

/// Helpers for semantic version comparison.
class VersionUtils {
  /// Tries to parse [value] as a [Version], returning null on failure.
  static Version? tryParse(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      return Version.parse(value);
    } on FormatException {
      return null;
    }
  }

  /// Tries to parse a version constraint.
  static VersionConstraint? tryParseConstraint(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      return VersionConstraint.parse(value);
    } on FormatException {
      return null;
    }
  }

  /// Whether [locked] is older than [latest].
  static bool isOutdated(String? locked, String? latest) {
    final a = tryParse(locked);
    final b = tryParse(latest);
    if (a == null || b == null) return false;
    return a < b;
  }

  /// Classifies the bump from [from] to [to].
  static VersionBump classifyBump(String? from, String? to) {
    final a = tryParse(from);
    final b = tryParse(to);
    if (a == null || b == null || a >= b) return VersionBump.none;
    if (b.major > a.major) return VersionBump.major;
    if (b.minor > a.minor) return VersionBump.minor;
    return VersionBump.patch;
  }

  /// Whether [sdkConstraint] allows [sdkVersion].
  static bool allowsSdk(String? sdkConstraint, String? sdkVersion) {
    final constraint = tryParseConstraint(sdkConstraint);
    final version = tryParse(sdkVersion);
    if (constraint == null || version == null) return true;
    return constraint.allows(version);
  }

  /// Extracts a concrete Dart SDK version from an environment constraint
  /// like `>=3.5.0 <4.0.0` by taking the minimum version when possible.
  static String? minimumSdkFromConstraint(String? constraint) {
    final parsed = tryParseConstraint(constraint);
    if (parsed is VersionRange) {
      return parsed.min?.toString();
    }
    if (parsed is Version) {
      return parsed.toString();
    }
    return null;
  }
}
