/// Typed metadata for a package fetched from pub.dev.
class PubDevPackageInfo {
  /// Creates package metadata.
  const PubDevPackageInfo({
    required this.name,
    required this.latestVersion,
    this.latestPublished,
    this.discontinued = false,
    this.replacedBy,
    this.versions = const [],
    this.sdkConstraint,
    this.score,
    this.notFound = false,
  });

  /// Package name.
  final String name;

  /// Latest published version string.
  final String latestVersion;

  /// When the latest version was published.
  final DateTime? latestPublished;

  /// Whether pub.dev marks the package as discontinued.
  final bool discontinued;

  /// Replacement package suggested by pub.dev, if any.
  final String? replacedBy;

  /// Known versions with retraction flags.
  final List<PubDevVersionInfo> versions;

  /// SDK constraint from the latest pubspec, if available.
  final String? sdkConstraint;

  /// Optional pub.dev score details.
  final PubDevScoreInfo? score;

  /// Whether the package was not found (404).
  final bool notFound;

  /// Returns version info for [version], or null.
  PubDevVersionInfo? versionInfo(String version) {
    for (final v in versions) {
      if (v.version == version) return v;
    }
    return null;
  }

  /// Whether [version] is marked as retracted.
  bool isRetracted(String version) => versionInfo(version)?.retracted ?? false;

  /// Builds from a pub.dev `/api/packages/<name>` JSON body.
  factory PubDevPackageInfo.fromPackageJson(
    Map<String, dynamic> json, {
    PubDevScoreInfo? score,
  }) {
    final latest = json['latest'] as Map<String, dynamic>? ?? const {};
    final latestPubspec =
        latest['pubspec'] as Map<String, dynamic>? ?? const {};
    final environment =
        latestPubspec['environment'] as Map<String, dynamic>? ?? const {};
    final sdk = environment['sdk']?.toString();

    final versionsJson = json['versions'] as List<dynamic>? ?? const [];
    final versions = versionsJson
        .whereType<Map>()
        .map((v) => PubDevVersionInfo.fromJson(Map<String, dynamic>.from(v)))
        .toList();

    DateTime? published;
    final publishedRaw = latest['published']?.toString();
    if (publishedRaw != null) {
      published = DateTime.tryParse(publishedRaw)?.toUtc();
    }

    // Official API uses `isDiscontinued` at the top level.
    final discontinuedFlag = json['isDiscontinued'] == true;

    return PubDevPackageInfo(
      name: (json['name'] ?? latestPubspec['name'] ?? '').toString(),
      latestVersion: (latest['version'] ?? '').toString(),
      latestPublished: published,
      discontinued: discontinuedFlag,
      replacedBy: json['replacedBy']?.toString(),
      versions: versions,
      sdkConstraint: sdk,
      score: score,
    );
  }

  /// Serializes to a JSON-compatible map.
  Map<String, Object?> toJson() => {
        'name': name,
        'latestVersion': latestVersion,
        'latestPublished': latestPublished?.toUtc().toIso8601String(),
        'discontinued': discontinued,
        'replacedBy': replacedBy,
        'versions': versions.map((v) => v.toJson()).toList(),
        'sdkConstraint': sdkConstraint,
        'score': score?.toJson(),
        'notFound': notFound,
      };
}

/// Metadata for a single published version.
class PubDevVersionInfo {
  /// Creates version metadata.
  const PubDevVersionInfo({
    required this.version,
    this.retracted = false,
    this.published,
  });

  /// Version string.
  final String version;

  /// Whether this version was retracted.
  final bool retracted;

  /// Publication timestamp.
  final DateTime? published;

  /// Parses from pub.dev version JSON.
  factory PubDevVersionInfo.fromJson(Map<String, dynamic> json) {
    DateTime? published;
    final raw = json['published']?.toString();
    if (raw != null) {
      published = DateTime.tryParse(raw)?.toUtc();
    }
    return PubDevVersionInfo(
      version: (json['version'] ?? '').toString(),
      retracted: json['retracted'] == true,
      published: published,
    );
  }

  /// Serializes to JSON.
  Map<String, Object?> toJson() => {
        'version': version,
        'retracted': retracted,
        'published': published?.toUtc().toIso8601String(),
      };
}

/// pub.dev package score details.
class PubDevScoreInfo {
  /// Creates score info.
  const PubDevScoreInfo({
    required this.grantedPoints,
    required this.maxPoints,
    this.likeCount = 0,
    this.downloadCount30Days = 0,
    this.tags = const [],
  });

  /// Granted pub points.
  final int grantedPoints;

  /// Maximum possible pub points.
  final int maxPoints;

  /// Like count.
  final int likeCount;

  /// Downloads in the last 30 days.
  final int downloadCount30Days;

  /// Package tags from the score API.
  final List<String> tags;

  /// Ratio of granted to max points (0–1).
  double get ratio => maxPoints == 0 ? 0 : grantedPoints / maxPoints;

  /// Parses from `/api/packages/<name>/score` JSON.
  factory PubDevScoreInfo.fromJson(Map<String, dynamic> json) {
    final tags =
        (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
            const [];
    return PubDevScoreInfo(
      grantedPoints: (json['grantedPoints'] as num?)?.toInt() ?? 0,
      maxPoints: (json['maxPoints'] as num?)?.toInt() ?? 0,
      likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
      downloadCount30Days: (json['downloadCount30Days'] as num?)?.toInt() ?? 0,
      tags: tags,
    );
  }

  /// Serializes to JSON.
  Map<String, Object?> toJson() => {
        'grantedPoints': grantedPoints,
        'maxPoints': maxPoints,
        'likeCount': likeCount,
        'downloadCount30Days': downloadCount30Days,
        'tags': tags,
      };
}
