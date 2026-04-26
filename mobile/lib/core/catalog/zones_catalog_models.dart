class ZonesCatalogManifest {
  const ZonesCatalogManifest({
    required this.catalog,
    required this.version,
    required this.publishedAtIso,
    required this.file,
    required this.checksum,
    required this.schemaVersion,
    required this.entries,
  });

  final String catalog;
  final int version;
  final String publishedAtIso;
  final String file;
  final String checksum;
  final int schemaVersion;
  final int entries;

  factory ZonesCatalogManifest.fromJson(Map<String, dynamic> json) {
    return ZonesCatalogManifest(
      catalog: (json['catalog'] as String?)?.trim() ?? '',
      version: (json['version'] as num?)?.toInt() ?? 0,
      publishedAtIso: (json['publishedAt'] as String?)?.trim() ?? '',
      file: (json['file'] as String?)?.trim() ?? '',
      checksum: (json['checksum'] as String?)?.trim() ?? '',
      schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 0,
      entries: (json['entries'] as num?)?.toInt() ?? 0,
    );
  }
}

class ZonesCatalogEntry {
  const ZonesCatalogEntry({
    required this.zoneId,
    required this.name,
    required this.normalizedName,
    required this.provinceId,
    required this.provinceName,
    required this.provinceNormalizedName,
    required this.departmentId,
    required this.departmentName,
    required this.departmentNormalizedName,
    required this.localityId,
    required this.localityName,
    required this.localityNormalizedName,
    required this.cityId,
    required this.countryId,
    required this.countryName,
    required this.status,
    required this.priorityLevel,
    this.centroidLat,
    this.centroidLng,
  });

  final String zoneId;
  final String name;
  final String normalizedName;
  final String provinceId;
  final String provinceName;
  final String provinceNormalizedName;
  final String departmentId;
  final String departmentName;
  final String departmentNormalizedName;
  final String localityId;
  final String localityName;
  final String localityNormalizedName;
  final String cityId;
  final String countryId;
  final String countryName;
  final String status;
  final int priorityLevel;
  final double? centroidLat;
  final double? centroidLng;

  String get searchIndexText => [
        normalizedName,
        localityNormalizedName,
        departmentNormalizedName,
        provinceNormalizedName,
        zoneId.toLowerCase(),
      ].join(' ');

  factory ZonesCatalogEntry.fromJson(Map<String, dynamic> json) {
    return ZonesCatalogEntry(
      zoneId: _readText(json, const ['zoneId', 'id']) ?? '',
      name: _readText(json, const ['name', 'localityName']) ?? '',
      normalizedName:
          _readText(json, const ['normalizedName', 'localityNormalizedName']) ??
              '',
      provinceId: _readText(json, const ['provinceId']) ?? '',
      provinceName: _readText(json, const ['provinceName']) ?? '',
      provinceNormalizedName:
          _readText(json, const ['provinceNormalizedName']) ?? '',
      departmentId: _readText(json, const ['departmentId']) ?? '',
      departmentName: _readText(json, const ['departmentName']) ?? '',
      departmentNormalizedName:
          _readText(json, const ['departmentNormalizedName']) ?? '',
      localityId: _readText(json, const ['localityId', 'zoneId', 'id']) ?? '',
      localityName: _readText(json, const ['localityName', 'name']) ?? '',
      localityNormalizedName:
          _readText(json, const ['localityNormalizedName', 'normalizedName']) ??
              '',
      cityId: _readText(json, const ['cityId', 'localityId', 'zoneId']) ?? '',
      countryId: _readText(json, const ['countryId']) ?? 'AR',
      countryName: _readText(json, const ['countryName']) ?? 'Argentina',
      status: _readText(json, const ['status']) ?? 'public_enabled',
      priorityLevel: (json['priorityLevel'] as num?)?.toInt() ?? 1 << 30,
      centroidLat: _readNumber(json, 'centroidLat'),
      centroidLng: _readNumber(json, 'centroidLng'),
    );
  }

  static String? _readText(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  static double? _readNumber(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is num) return value.toDouble();
    return null;
  }
}

class ZonesCatalogData {
  const ZonesCatalogData({
    required this.version,
    required this.schemaVersion,
    required this.generatedAtIso,
    required this.entries,
    required this.zones,
  });

  final int version;
  final int schemaVersion;
  final String generatedAtIso;
  final int entries;
  final List<ZonesCatalogEntry> zones;

  factory ZonesCatalogData.fromJson(Map<String, dynamic> json) {
    final rawZones = (json['zones'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((zone) => Map<String, dynamic>.from(zone))
        .toList(growable: false);

    final zones = rawZones
        .map(ZonesCatalogEntry.fromJson)
        .where((zone) => zone.zoneId.isNotEmpty)
        .toList(growable: false);

    return ZonesCatalogData(
      version: (json['version'] as num?)?.toInt() ?? 0,
      schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 0,
      generatedAtIso: (json['generatedAt'] as String?)?.trim() ?? '',
      entries: (json['entries'] as num?)?.toInt() ?? zones.length,
      zones: zones,
    );
  }
}

class ZonesCatalogLoadState {
  const ZonesCatalogLoadState({
    required this.catalog,
    required this.source,
    required this.wasUpdated,
    required this.previousVersion,
    required this.currentVersion,
  });

  final ZonesCatalogData catalog;
  final String source;
  final bool wasUpdated;
  final int previousVersion;
  final int currentVersion;
}
