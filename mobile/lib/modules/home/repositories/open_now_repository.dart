import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/catalog/zones_catalog_models.dart';
import '../../../core/catalog/zones_catalog_repository.dart';
import '../models/open_now_models.dart';

abstract interface class OpenNowDataSource {
  Future<List<OpenNowZone>> fetchZones();

  Future<List<OpenNowMerchant>> fetchOpenNow({
    required String zoneId,
    int limit,
  });

  Future<List<OpenNowMerchant>> fetchFallback({
    required String zoneId,
    int limit,
  });
}

class OpenNowRepository implements OpenNowDataSource {
  static const Set<String> _inactiveZoneStatuses = <String>{
    'draft',
    'internal_test',
    'paused',
    'borrador',
    'pausado',
    'pausada',
  };

  OpenNowRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _catalogRepository = ZonesCatalogRepository();

  OpenNowRepository.withCatalogRepository({
    FirebaseFirestore? firestore,
    required ZonesCatalogRepository catalogRepository,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _catalogRepository = catalogRepository;

  final FirebaseFirestore _firestore;
  final ZonesCatalogRepository _catalogRepository;

  static const Duration _queryTimeout = Duration(seconds: 8);
  static const int _openNowLimit = 200;
  static const int _fallbackLimit = 40;

  @override
  Future<List<OpenNowZone>> fetchZones() async {
    final state = await _catalogRepository.loadCatalog();
    final active = state.catalog.zones.where(_isActiveZoneRecord).toList();
    active.sort(_compareZoneRecords);
    return active.map(OpenNowZone.fromCatalogEntry).toList(growable: false);
  }

  static bool _isActiveZoneRecord(ZonesCatalogEntry zone) {
    final status = zone.status.toLowerCase();
    if (status.isEmpty) return true;
    return !_inactiveZoneStatuses.contains(status);
  }

  static int _compareZoneRecords(
    ZonesCatalogEntry a,
    ZonesCatalogEntry b,
  ) {
    final priorityCompare = _zonePriority(a).compareTo(_zonePriority(b));
    if (priorityCompare != 0) return priorityCompare;
    final nameCompare = a.name.toLowerCase().compareTo(b.name.toLowerCase());
    if (nameCompare != 0) return nameCompare;
    return a.zoneId.compareTo(b.zoneId);
  }

  static int _zonePriority(ZonesCatalogEntry data) {
    return data.priorityLevel;
  }

  @override
  Future<List<OpenNowMerchant>> fetchOpenNow({
    required String zoneId,
    int limit = _openNowLimit,
  }) async {
    if (zoneId.trim().isEmpty) return const [];
    final snapshot = await _firestore
        .collection('merchant_public')
        .where('zoneId', isEqualTo: zoneId)
        .where('visibilityStatus', isEqualTo: 'visible')
        .where('isOpenNow', isEqualTo: true)
        .limit(limit)
        .get()
        .timeout(_queryTimeout);

    return snapshot.docs
        .map(OpenNowMerchant.fromFirestore)
        .toList(growable: false);
  }

  @override
  Future<List<OpenNowMerchant>> fetchFallback({
    required String zoneId,
    int limit = _fallbackLimit,
  }) async {
    if (zoneId.trim().isEmpty) return const [];
    final snapshot = await _firestore
        .collection('merchant_public')
        .where('zoneId', isEqualTo: zoneId)
        .where('visibilityStatus', isEqualTo: 'visible')
        .where('isOpenNow', isEqualTo: false)
        .limit(limit)
        .get()
        .timeout(_queryTimeout);

    final items =
        snapshot.docs.map(OpenNowMerchant.fromFirestore).where((merchant) {
      final label = merchant.effectiveScheduleLabel.trim();
      return label.isNotEmpty;
    });

    return items.toList(growable: false);
  }
}
