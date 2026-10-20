import '../models/pub_dev_package_info.dart';

/// In-memory cache of pub.dev package metadata for a single analysis run.
class PubDevCache {
  final Map<String, PubDevPackageInfo> _packages = {};
  final Map<String, PubDevScoreInfo> _scores = {};

  /// Returns cached package info, if any.
  PubDevPackageInfo? getPackage(String name) => _packages[name];

  /// Stores package info.
  void putPackage(String name, PubDevPackageInfo info) {
    _packages[name] = info;
  }

  /// Returns cached score info, if any.
  PubDevScoreInfo? getScore(String name) => _scores[name];

  /// Stores score info.
  void putScore(String name, PubDevScoreInfo score) {
    _scores[name] = score;
  }

  /// Whether package [name] is already cached.
  bool containsPackage(String name) => _packages.containsKey(name);

  /// Clears all cached entries.
  void clear() {
    _packages.clear();
    _scores.clear();
  }
}
