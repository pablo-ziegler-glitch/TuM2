import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/cache/zones_cache_service.dart';
import '../models/pharmacy_zone.dart';

abstract interface class ZonesSource {
  Future<List<PharmacyZone>> getActiveZones();
}

/// Repositorio de zonas geográficas para el selector manual.
///
/// Solo retorna zonas activas (pilot_enabled o public_enabled).
class ZonesRepository implements ZonesSource {
  static const Set<String> _inactiveZoneStatuses = <String>{
    'draft',
    'internal_test',
    'paused',
    'borrador',
    'pausado',
    'pausada',
  };

  final ZonesCacheService _zonesCache;

  static const Duration _queryTimeout = Duration(seconds: 5);

  ZonesRepository({FirebaseFirestore? firestore})
      : _zonesCache = ZonesCacheService(firestore: firestore);

  /// Retorna todas las zonas con status 'pilot_enabled' o 'public_enabled',
  /// ordenadas por [priorityLevel] ascendente.
  @override
  Future<List<PharmacyZone>> getActiveZones() async {
    final zones = await _zonesCache.fetchZones(timeout: _queryTimeout);
    final active = zones.where(_isActiveZoneRecord).toList();
    active.sort(_compareZoneRecords);
    return active
        .map((zone) => PharmacyZone.fromMap(zone.id, zone.data))
        .toList(growable: false);
  }

  static bool _isActiveZoneRecord(ZoneCacheRecord zone) {
    final status =
        _readText(zone.data, const ['status', 'estado'])?.toLowerCase();
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
    final nameCompare = (_readText(a.data, const ['name', 'nombre']) ?? a.id)
        .toLowerCase()
        .compareTo(
          (_readText(b.data, const ['name', 'nombre']) ?? b.id).toLowerCase(),
        );
    if (nameCompare != 0) return nameCompare;
    return a.id.compareTo(b.id);
  }

  static int _zonePriority(Map<String, dynamic> data) {
    final rawPriority =
        data['priorityLevel'] ?? data['priority'] ?? data['prioridad'];
    return rawPriority is num ? rawPriority.toInt() : 1 << 30;
  }

  static String? _readText(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }
}
