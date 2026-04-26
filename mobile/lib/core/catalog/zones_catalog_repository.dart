import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../analytics/analytics_runtime.dart';
import '../firebase/app_environment.dart';
import 'text_normalizer.dart';
import 'zones_catalog_models.dart';

typedef ZonesPreferencesLoader = Future<SharedPreferences> Function();

class ZonesCatalogRepository {
  ZonesCatalogRepository({
    http.Client? httpClient,
    ZonesPreferencesLoader? preferencesLoader,
    AssetBundle? assetBundle,
    DateTime Function()? now,
  })  : _httpClient = httpClient ?? http.Client(),
        _preferencesLoader = preferencesLoader ?? SharedPreferences.getInstance,
        _assetBundle = assetBundle ?? rootBundle,
        _now = now ?? DateTime.now;

  final http.Client _httpClient;
  final ZonesPreferencesLoader _preferencesLoader;
  final AssetBundle _assetBundle;
  final DateTime Function() _now;

  static const _seedAssetPath = 'assets/catalogs/zones/seed/zones-seed.json';
  static const _requestTimeout = Duration(seconds: 5);
  static const _manifestCheckTtl = Duration(minutes: 20);

  static const _cacheJsonKey = 'tum2.catalog.zones.cache_json.v1';
  static const _manifestCheckedAtKey =
      'tum2.catalog.zones.manifest_checked_at.v1';

  static Future<ZonesCatalogLoadState>? _inFlight;
  static ZonesCatalogData? _memoryCatalog;
  static DateTime? _memoryLoadedAt;
  static int _indexedCatalogVersion = -1;
  static List<ZonesCatalogEntry> _indexedZones = const [];
  static Map<String, List<int>> _tokenToZoneIndexes = const {};
  static Map<String, Set<int>> _tokenToZoneIndexSets = const {};

  @visibleForTesting
  static void resetForTest() {
    _inFlight = null;
    _memoryCatalog = null;
    _memoryLoadedAt = null;
    _indexedCatalogVersion = -1;
    _indexedZones = const [];
    _tokenToZoneIndexes = const {};
    _tokenToZoneIndexSets = const {};
  }

  Future<ZonesCatalogLoadState> loadCatalog({
    bool forceManifestCheck = false,
  }) async {
    final inFlight = _inFlight;
    if (inFlight != null) return inFlight;
    final future = _doLoadCatalog(forceManifestCheck: forceManifestCheck);
    _inFlight = future;
    return future.whenComplete(() => _inFlight = null);
  }

  Future<ZonesCatalogLoadState> _doLoadCatalog({
    required bool forceManifestCheck,
  }) async {
    final startedAt = _now();
    await _track('zones_catalog_load_started', <String, Object?>{
      'platform': kIsWeb ? 'web' : 'mobile',
    });

    final prefs = await _preferencesLoader();
    final memory = _memoryCatalog;
    final now = _now().toUtc();
    if (memory != null && _memoryLoadedAt != null) {
      final state = ZonesCatalogLoadState(
        catalog: memory,
        source: 'memory',
        wasUpdated: false,
        previousVersion: memory.version,
        currentVersion: memory.version,
      );
      if (!_shouldCheckManifest(prefs, now, forceManifestCheck)) {
        await _track('zones_catalog_load_succeeded', <String, Object?>{
          'platform': kIsWeb ? 'web' : 'mobile',
          'load_source': 'memory',
          'catalog_version_current': memory.version,
          'result': 'ok',
          'latency_ms': _now().difference(startedAt).inMilliseconds,
        });
        return state;
      }
    }

    ZonesCatalogData? catalog;
    var source = 'seed';

    final cachedJson = prefs.getString(_cacheJsonKey);
    if (cachedJson != null && cachedJson.trim().isNotEmpty) {
      final parsed = _parseCatalog(cachedJson);
      if (parsed != null && parsed.version > 0) {
        catalog = parsed;
        source = 'cache';
      }
    }

    if (catalog == null) {
      final seed = await _loadSeedCatalog();
      catalog = seed;
      source = 'seed';
    }

    final previousVersion = catalog.version;
    var wasUpdated = false;
    if (_shouldCheckManifest(prefs, now, forceManifestCheck)) {
      final update = await _tryUpdateFromRemote(
        current: catalog,
        prefs: prefs,
      );
      if (update != null) {
        catalog = update.catalog;
        source = update.source;
        wasUpdated = update.wasUpdated;
      }
      await prefs.setInt(
        _manifestCheckedAtKey,
        now.millisecondsSinceEpoch,
      );
    }

    _memoryCatalog = catalog;
    _memoryLoadedAt = now;

    await _track('zones_catalog_load_succeeded', <String, Object?>{
      'platform': kIsWeb ? 'web' : 'mobile',
      'load_source': source,
      'catalog_version_current': catalog.version,
      'result': 'ok',
      'latency_ms': _now().difference(startedAt).inMilliseconds,
    });

    return ZonesCatalogLoadState(
      catalog: catalog,
      source: source,
      wasUpdated: wasUpdated,
      previousVersion: previousVersion,
      currentVersion: catalog.version,
    );
  }

  Future<ZonesCatalogData> _loadSeedCatalog() async {
    final raw = await _assetBundle.loadString(_seedAssetPath);
    final catalog = _parseCatalog(raw);
    if (catalog == null) {
      throw StateError('No se pudo parsear seed local de zonas.');
    }
    return catalog;
  }

  bool _shouldCheckManifest(
    SharedPreferences prefs,
    DateTime now,
    bool forceManifestCheck,
  ) {
    if (forceManifestCheck) return true;
    final checkedAtMs = prefs.getInt(_manifestCheckedAtKey);
    if (checkedAtMs == null || checkedAtMs <= 0) return true;
    final checkedAt = DateTime.fromMillisecondsSinceEpoch(
      checkedAtMs,
      isUtc: true,
    );
    return now.difference(checkedAt) >= _manifestCheckTtl;
  }

  Future<({ZonesCatalogData catalog, String source, bool wasUpdated})?>
      _tryUpdateFromRemote({
    required ZonesCatalogData current,
    required SharedPreferences prefs,
  }) async {
    try {
      final manifestUrl = _manifestUrl();
      final manifestResponse = await _httpClient
          .get(Uri.parse(manifestUrl))
          .timeout(_requestTimeout);
      if (manifestResponse.statusCode != 200) {
        await _track('zones_catalog_load_failed', <String, Object?>{
          'platform': kIsWeb ? 'web' : 'mobile',
          'result': 'manifest_http_${manifestResponse.statusCode}',
          'catalog_version_current': current.version,
        });
        return null;
      }
      final manifest = ZonesCatalogManifest.fromJson(
        Map<String, dynamic>.from(
          jsonDecode(manifestResponse.body) as Map,
        ),
      );

      await _track('zones_catalog_manifest_checked', <String, Object?>{
        'platform': kIsWeb ? 'web' : 'mobile',
        'catalog_version_current': current.version,
        'catalog_version_new': manifest.version,
        'result': manifest.version == current.version
            ? 'same'
            : (manifest.version > current.version ? 'upgrade' : 'rollback'),
      });

      if (manifest.version == current.version) return null;

      final fileUrl = _catalogFileUrl(manifest.file);
      final fileResponse =
          await _httpClient.get(Uri.parse(fileUrl)).timeout(_requestTimeout);
      if (fileResponse.statusCode != 200) {
        await _track('zones_catalog_load_failed', <String, Object?>{
          'platform': kIsWeb ? 'web' : 'mobile',
          'result': 'catalog_http_${fileResponse.statusCode}',
          'catalog_version_current': current.version,
          'catalog_version_new': manifest.version,
        });
        return null;
      }

      final catalogBody = fileResponse.body;
      if (!_validateChecksum(catalogBody, manifest.checksum)) {
        await _track('zones_catalog_load_failed', <String, Object?>{
          'platform': kIsWeb ? 'web' : 'mobile',
          'result': 'checksum_mismatch',
          'catalog_version_current': current.version,
          'catalog_version_new': manifest.version,
        });
        return null;
      }

      final parsed = _parseCatalog(catalogBody);
      if (parsed == null || parsed.version != manifest.version) {
        await _track('zones_catalog_load_failed', <String, Object?>{
          'platform': kIsWeb ? 'web' : 'mobile',
          'result': 'invalid_catalog_payload',
          'catalog_version_current': current.version,
          'catalog_version_new': manifest.version,
        });
        return null;
      }

      await prefs.setString(_cacheJsonKey, catalogBody);

      await _track('zones_catalog_updated', <String, Object?>{
        'platform': kIsWeb ? 'web' : 'mobile',
        'catalog_version_current': current.version,
        'catalog_version_new': parsed.version,
        'result': parsed.version > current.version ? 'upgrade' : 'rollback',
      });

      return (catalog: parsed, source: 'remote', wasUpdated: true);
    } catch (error) {
      await _track('zones_catalog_load_failed', <String, Object?>{
        'platform': kIsWeb ? 'web' : 'mobile',
        'result': 'remote_exception',
        'catalog_version_current': current.version,
      });
      return null;
    }
  }

  ZonesCatalogData? _parseCatalog(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final catalog =
          ZonesCatalogData.fromJson(Map<String, dynamic>.from(decoded));
      if (catalog.zones.isEmpty) return null;
      return catalog;
    } catch (_) {
      return null;
    }
  }

  bool _validateChecksum(String raw, String expectedChecksum) {
    if (expectedChecksum.trim().isEmpty) return false;
    final digest = sha256.convert(utf8.encode(raw)).bytes;
    final actual = 'sha256-${base64.encode(digest)}';
    return actual == expectedChecksum;
  }

  Future<List<ZonesCatalogEntry>> search({
    required String query,
    int limit = 60,
  }) async {
    final state = await loadCatalog();
    _ensureSearchIndex(state.catalog);
    final normalizedQuery = normalizeCatalogText(query);
    if (normalizedQuery.isEmpty) {
      return _indexedZones.take(limit).toList(growable: false);
    }
    final tokens = normalizedQuery
        .split(' ')
        .where((token) => token.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (tokens.isEmpty) {
      return _indexedZones.take(limit).toList(growable: false);
    }
    for (final token in tokens) {
      if (!_tokenToZoneIndexes.containsKey(token)) return const [];
    }

    var anchorToken = tokens.first;
    for (final token in tokens.skip(1)) {
      final currentLen = _tokenToZoneIndexes[token]!.length;
      final anchorLen = _tokenToZoneIndexes[anchorToken]!.length;
      if (currentLen < anchorLen) anchorToken = token;
    }

    final anchorIndexes = _tokenToZoneIndexes[anchorToken]!;
    final matches = <ZonesCatalogEntry>[];
    for (final index in anchorIndexes) {
      var ok = true;
      for (final token in tokens) {
        if (!_tokenToZoneIndexSets[token]!.contains(index)) {
          ok = false;
          break;
        }
      }
      if (!ok) continue;
      matches.add(_indexedZones[index]);
      if (matches.length >= limit) break;
    }
    return matches;
  }

  void _ensureSearchIndex(ZonesCatalogData catalog) {
    if (_indexedCatalogVersion == catalog.version &&
        _indexedZones.length == catalog.zones.length &&
        _tokenToZoneIndexes.isNotEmpty) {
      return;
    }

    final zoneIndexes = <String, List<int>>{};
    final zoneIndexSets = <String, Set<int>>{};
    final zones = catalog.zones;
    for (var i = 0; i < zones.length; i++) {
      final tokens = zones[i]
          .searchIndexText
          .split(' ')
          .where((token) => token.isNotEmpty)
          .toSet();
      for (final token in tokens) {
        zoneIndexes.putIfAbsent(token, () => <int>[]).add(i);
        zoneIndexSets.putIfAbsent(token, () => <int>{}).add(i);
      }
    }

    _indexedCatalogVersion = catalog.version;
    _indexedZones = zones;
    _tokenToZoneIndexes = zoneIndexes;
    _tokenToZoneIndexSets = zoneIndexSets;
  }

  String _manifestUrl() {
    final env = _environmentSegment();
    if (kIsWeb) return '/catalogs/zones/$env/manifest.json';
    final host = _mobileHostingHostByEnvironment();
    return 'https://$host.web.app/catalogs/zones/$env/manifest.json';
  }

  String _catalogFileUrl(String filePath) {
    if (kIsWeb) return filePath;
    final host = _mobileHostingHostByEnvironment();
    return 'https://$host.web.app$filePath';
  }

  String _environmentSegment() {
    return switch (AppEnvironmentConfig.current) {
      AppEnvironment.dev => 'dev',
      AppEnvironment.staging => 'staging',
      AppEnvironment.prod => 'prod',
    };
  }

  String _mobileHostingHostByEnvironment() {
    return switch (AppEnvironmentConfig.current) {
      AppEnvironment.dev => 'tum2-dev-6283d',
      AppEnvironment.staging => 'tum2-staging-45c83',
      AppEnvironment.prod => 'tum2-web-prod',
    };
  }

  Future<void> _track(String event, Map<String, Object?> parameters) async {
    try {
      await AnalyticsRuntime.service.track(
        event: event,
        parameters: parameters,
      );
    } catch (_) {
      // Evita frenar el flujo principal por analítica.
    }
  }
}
