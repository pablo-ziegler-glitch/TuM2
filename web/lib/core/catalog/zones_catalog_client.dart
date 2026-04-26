import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase/firebase_bootstrap.dart';

class ZonesCatalogClient {
  ZonesCatalogClient({
    http.Client? httpClient,
    AssetBundle? assetBundle,
    Future<SharedPreferences> Function()? preferencesLoader,
  })  : _httpClient = httpClient ?? http.Client(),
        _assetBundle = assetBundle ?? rootBundle,
        _preferencesLoader = preferencesLoader ?? SharedPreferences.getInstance;

  final http.Client _httpClient;
  final AssetBundle _assetBundle;
  final Future<SharedPreferences> Function() _preferencesLoader;

  static const _seedAssetPath = 'assets/catalogs/zones/seed/zones-seed.json';
  static const _cacheJsonKey = 'tum2_admin.catalog.zones.cache_json.v1';
  static const _manifestCheckedAtKey =
      'tum2_admin.catalog.zones.manifest_checked_at.v1';
  static const _manifestCheckTtl = Duration(minutes: 20);
  static const _requestTimeout = Duration(seconds: 5);

  static Future<List<Map<String, dynamic>>>? _inFlight;
  static List<Map<String, dynamic>>? _memoryZones;
  static int _memoryVersion = 0;

  Future<List<Map<String, dynamic>>> loadZones({
    bool forceManifestCheck = false,
  }) async {
    final inFlight = _inFlight;
    if (inFlight != null) return inFlight;
    final future = _doLoadZones(forceManifestCheck: forceManifestCheck);
    _inFlight = future;
    return future.whenComplete(() => _inFlight = null);
  }

  @visibleForTesting
  static void resetForTest() {
    _inFlight = null;
    _memoryZones = null;
    _memoryVersion = 0;
  }

  Future<List<Map<String, dynamic>>> _doLoadZones({
    required bool forceManifestCheck,
  }) async {
    final prefs = await _preferencesLoader();
    final cached = _memoryZones;
    if (cached != null &&
        !forceManifestCheck &&
        !_shouldCheckManifest(prefs, DateTime.now().toUtc())) {
      return List<Map<String, dynamic>>.unmodifiable(cached);
    }

    final persistedRaw = prefs.getString(_cacheJsonKey);
    if (persistedRaw != null && persistedRaw.trim().isNotEmpty) {
      final parsed = _parseCatalog(persistedRaw);
      if (parsed != null) {
        _memoryZones = parsed.zones;
        _memoryVersion = parsed.version;
      }
    }

    if (_memoryZones == null) {
      final seedRaw = await _assetBundle.loadString(_seedAssetPath);
      final parsed = _parseCatalog(seedRaw);
      if (parsed != null) {
        _memoryZones = parsed.zones;
        _memoryVersion = parsed.version;
      } else {
        _memoryZones = const <Map<String, dynamic>>[];
        _memoryVersion = 0;
      }
    }

    if (forceManifestCheck ||
        _shouldCheckManifest(prefs, DateTime.now().toUtc())) {
      await _tryRemoteUpdate(prefs);
      await prefs.setInt(
        _manifestCheckedAtKey,
        DateTime.now().toUtc().millisecondsSinceEpoch,
      );
    }

    return List<Map<String, dynamic>>.unmodifiable(_memoryZones!);
  }

  Future<void> _tryRemoteUpdate(SharedPreferences prefs) async {
    final env = _resolveEnvironmentSegment();
    final manifestUrl = '/catalogs/zones/$env/manifest.json';
    try {
      final manifestResponse = await _httpClient
          .get(Uri.parse(manifestUrl))
          .timeout(_requestTimeout);
      if (manifestResponse.statusCode != 200) return;
      final manifest = Map<String, dynamic>.from(
        jsonDecode(manifestResponse.body) as Map,
      );
      final remoteVersion = (manifest['version'] as num?)?.toInt() ?? 0;
      if (remoteVersion == _memoryVersion) return;
      final filePath = (manifest['file'] as String?)?.trim() ?? '';
      if (filePath.isEmpty) return;
      final checksum = (manifest['checksum'] as String?)?.trim() ?? '';
      final fileResponse =
          await _httpClient.get(Uri.parse(filePath)).timeout(_requestTimeout);
      if (fileResponse.statusCode != 200) return;
      final payload = fileResponse.body;
      if (!_validateChecksum(payload, checksum)) return;
      final parsed = _parseCatalog(payload);
      if (parsed == null || parsed.version != remoteVersion) return;
      _memoryZones = parsed.zones;
      _memoryVersion = parsed.version;
      await prefs.setString(_cacheJsonKey, payload);
    } catch (_) {
      // Mantiene catálogo vigente en cache/seed ante fallas de red.
    }
  }

  ({int version, List<Map<String, dynamic>> zones})? _parseCatalog(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final map = Map<String, dynamic>.from(decoded);
      final version = (map['version'] as num?)?.toInt() ?? 0;
      final zonesRaw = (map['zones'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((zone) => Map<String, dynamic>.from(zone))
          .toList(growable: false);
      if (zonesRaw.isEmpty) return null;
      return (version: version, zones: zonesRaw);
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

  bool _shouldCheckManifest(SharedPreferences prefs, DateTime nowUtc) {
    final checkedAtMs = prefs.getInt(_manifestCheckedAtKey);
    if (checkedAtMs == null || checkedAtMs <= 0) return true;
    final checkedAt =
        DateTime.fromMillisecondsSinceEpoch(checkedAtMs, isUtc: true);
    return nowUtc.difference(checkedAt) >= _manifestCheckTtl;
  }

  String _resolveEnvironmentSegment() {
    final projectId = FirebaseBootstrap.currentProjectId;
    if (projectId == 'tum2-dev-6283d') return 'dev';
    if (projectId == 'tum2-staging-45c83') return 'staging';
    return 'prod';
  }
}
