import 'package:cloud_firestore/cloud_firestore.dart';

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
  OpenNowRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const Duration _queryTimeout = Duration(seconds: 6);
  static const int _openNowLimit = 200;
  static const int _fallbackLimit = 40;

  @override
  Future<List<OpenNowZone>> fetchZones() async {
    final snapshot = await _firestore
        .collection('zones')
        .where('status', whereIn: ['pilot_enabled', 'public_enabled'])
        .orderBy('priorityLevel')
        .get()
        .timeout(_queryTimeout);

    return snapshot.docs.map(OpenNowZone.fromFirestore).toList(growable: false);
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
