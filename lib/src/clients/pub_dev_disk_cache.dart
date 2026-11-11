import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/pub_dev_package_info.dart';

/// Persistent cache of pub.dev responses, shared between runs.
///
/// Entries are stored as `<dir>/<host>/<package>.json` and expire after
/// [ttl]. Expired entries are still returned when explicitly requested (for
/// offline mode or when pub.dev is unreachable).
class PubDevDiskCache {
  /// Creates a disk cache rooted at [directory] for the pub host [baseUrl].
  PubDevDiskCache({
    required String directory,
    required String baseUrl,
    this.ttl = const Duration(hours: 6),
    DateTime Function()? clock,
  })  : _dir = Directory(p.join(directory, _hostSegment(baseUrl))),
        _clock = clock ?? DateTime.now;

  /// How long an entry is considered fresh.
  final Duration ttl;

  final Directory _dir;
  final DateTime Function() _clock;

  /// The directory entries are written to.
  String get path => _dir.path;

  static String _hostSegment(String baseUrl) =>
      baseUrl.replaceAll(RegExp(r'^[a-z]+://'), '').replaceAll(
            RegExp(r'[^A-Za-z0-9._-]'),
            '_',
          );

  /// Resolves the default cache directory for the current platform.
  ///
  /// Order: `PUB_HEALTH_CACHE_DIR`, `XDG_CACHE_HOME`, `~/.cache`,
  /// `%LOCALAPPDATA%`, then the system temp directory.
  static String defaultDirectory([Map<String, String>? environment]) {
    final env = environment ?? Platform.environment;
    final explicit = env['PUB_HEALTH_CACHE_DIR'];
    if (explicit != null && explicit.isNotEmpty) return explicit;
    final xdg = env['XDG_CACHE_HOME'];
    if (xdg != null && xdg.isNotEmpty) return p.join(xdg, 'pub_health');
    final home = env['HOME'] ?? env['USERPROFILE'];
    final local = env['LOCALAPPDATA'];
    if (local != null && local.isNotEmpty && Platform.isWindows) {
      return p.join(local, 'pub_health', 'cache');
    }
    if (home != null && home.isNotEmpty) {
      return p.join(home, '.cache', 'pub_health');
    }
    return p.join(Directory.systemTemp.path, 'pub_health_cache');
  }

  File _file(String name) => File(p.join(_dir.path, '$name.json'));

  /// Reads a cached package, or null if absent, corrupt, or (unless
  /// [allowStale]) older than [ttl].
  Future<PubDevPackageInfo?> read(
    String name, {
    bool allowStale = false,
  }) async {
    final entry = await readEntry(name);
    if (entry == null) return null;
    if (!allowStale && _clock().toUtc().difference(entry.cachedAt) > ttl) {
      return null;
    }
    return entry.info;
  }

  /// Reads a cache entry including its timestamp.
  Future<CachedPackage?> readEntry(String name) async {
    final file = _file(name);
    try {
      if (!await file.exists()) return null;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) return null;
      final cachedAt = DateTime.tryParse('${decoded['cachedAt']}');
      final info = decoded['info'];
      if (cachedAt == null || info is! Map<String, dynamic>) return null;
      return CachedPackage(
        cachedAt: cachedAt.toUtc(),
        info: PubDevPackageInfo.fromCacheJson(info),
      );
    } on FormatException {
      return null; // Corrupt entry: treat as a miss.
    } on FileSystemException {
      return null;
    }
  }

  /// Stores [info]. Failures are ignored: caching is best-effort.
  Future<void> write(String name, PubDevPackageInfo info) async {
    try {
      await _dir.create(recursive: true);
      final payload = jsonEncode({
        'cachedAt': _clock().toUtc().toIso8601String(),
        'info': info.toJson(),
      });
      // Write to a temp file first so concurrent runs never see a partial
      // JSON document.
      final tmp = File('${_file(name).path}.$pid.tmp');
      await tmp.writeAsString(payload);
      await tmp.rename(_file(name).path);
    } on FileSystemException {
      // Read-only file system, quota, etc. — not worth failing the run.
    }
  }

  /// Deletes every cached entry for this host.
  Future<void> clear() async {
    if (await _dir.exists()) {
      await _dir.delete(recursive: true);
    }
  }
}

/// A cache entry with its timestamp.
class CachedPackage {
  /// Creates a cache entry.
  const CachedPackage({required this.cachedAt, required this.info});

  /// When the entry was written (UTC).
  final DateTime cachedAt;

  /// Cached metadata.
  final PubDevPackageInfo info;
}
