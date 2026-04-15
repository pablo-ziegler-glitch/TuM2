import 'package:cloud_firestore/cloud_firestore.dart';

class ZoneCacheRecord {
  const ZoneCacheRecord({
    required this.id,
    required this.data,
  });

  final String id;
  final Map<String, dynamic> data;
}

class ZonesCacheService {
  ZonesCacheService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const String _zoneCollection = 'zones';
  static const int _maxZonesPerQuery = 300;
  static const int _cacheTtlSeconds = int.fromEnvironment(
    'ZONES_CACHE_TTL_SECONDS',
    defaultValue: 300,
  );

  static List<ZoneCacheRecord>? _cache;
  static DateTime? _expiresAtUtc;
  static Future<List<ZoneCacheRecord>>? _inFlight;

  Future<List<ZoneCacheRecord>> fetchZones({
    bool forceRefresh = false,
    Duration timeout = const Duration(seconds: 6),
  }) async {
    final now = DateTime.now().toUtc();
    if (!forceRefresh &&
        _cache != null &&
        _expiresAtUtc != null &&
        now.isBefore(_expiresAtUtc!)) {
      return List<ZoneCacheRecord>.unmodifiable(_cache!);
    }

    final inFlight = _inFlight;
    if (!forceRefresh && inFlight != null) {
      return inFlight;
    }

    final fetch = _firestore
        .collection(_zoneCollection)
        .limit(_maxZonesPerQuery)
        .get()
        .timeout(timeout)
        .then((snapshot) {
      final items = snapshot.docs
          .map(
            (doc) => ZoneCacheRecord(
              id: doc.id,
              data: Map<String, dynamic>.from(doc.data()),
            ),
          )
          .toList(growable: false);
      _cache = items;
      _expiresAtUtc =
          DateTime.now().toUtc().add(const Duration(seconds: _cacheTtlSeconds));
      return List<ZoneCacheRecord>.unmodifiable(items);
    }).whenComplete(() {
      _inFlight = null;
    });

    _inFlight = fetch;
    return fetch;
  }
}
