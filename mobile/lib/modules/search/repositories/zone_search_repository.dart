import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/cache/zones_cache_service.dart';
import '../models/search_zone_item.dart';

abstract interface class ZoneSearchDataSource {
  Future<List<SearchZoneItem>> fetchAvailableZones();
}

class ZoneSearchRepository implements ZoneSearchDataSource {
  static const Set<String> _inactiveZoneStatuses = <String>{
    'draft',
    'internal_test',
    'paused',
    'borrador',
    'pausado',
    'pausada',
  };

  ZoneSearchRepository({FirebaseFirestore? firestore})
      : _zonesCache = ZonesCacheService(firestore: firestore);

  final ZonesCacheService _zonesCache;
  static const Duration _queryTimeout = Duration(seconds: 6);

  @override
  Future<List<SearchZoneItem>> fetchAvailableZones() async {
    final zones = await _zonesCache.fetchZones(timeout: _queryTimeout);
    final active = zones.where(_isActiveZoneRecord).toList();
    active.sort(_compareZoneRecords);
    return active
        .map((zone) => SearchZoneItem.fromMap(zone.id, zone.data))
        .toList(growable: false);
  }

  static bool _isActiveZoneRecord(ZoneCacheRecord zone) {
    final data = zone.data;
    final status = SearchZoneItem.readText(
      data,
      const ['status', 'estado'],
    )?.toLowerCase();
    if (status == null || status.isEmpty) return true;
    return !_inactiveZoneStatuses.contains(status);
  }

  static int _compareZoneRecords(
    ZoneCacheRecord a,
    ZoneCacheRecord b,
  ) {
    final priorityCompare =
        _zonePriority(a.data).compareTo(_zonePriority(b.data));
    if (priorityCompare != 0) return priorityCompare;
    final nameCompare = (SearchZoneItem.readText(
              a.data,
              const ['name', 'nombre'],
            ) ??
            a.id)
        .toLowerCase()
        .compareTo(
          (SearchZoneItem.readText(
                    b.data,
                    const ['name', 'nombre'],
                  ) ??
                  b.id)
              .toLowerCase(),
        );
    if (nameCompare != 0) return nameCompare;
    return a.id.compareTo(b.id);
  }

  static int _zonePriority(Map<String, dynamic> data) {
    final rawPriority =
        data['priorityLevel'] ?? data['priority'] ?? data['prioridad'];
    return rawPriority is num ? rawPriority.toInt() : 1 << 30;
  }
}
