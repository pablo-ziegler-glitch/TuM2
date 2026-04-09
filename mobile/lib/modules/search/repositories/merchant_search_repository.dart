import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/merchant_search_item.dart';

abstract interface class MerchantSearchDataSource {
  Future<List<MerchantSearchItem>> fetchZoneCorpus(
    String zoneId, {
    List<String> visibilityStatuses,
  });
}

class MerchantSearchRepository implements MerchantSearchDataSource {
  MerchantSearchRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const Duration _queryTimeout = Duration(seconds: 6);
  static const _maxCorpus = 200;
  static const _legacyZoneFallbackEnabled = bool.fromEnvironment(
    'SEARCH_LEGACY_ZONE_FALLBACK',
    defaultValue: false,
  );

  @override
  Future<List<MerchantSearchItem>> fetchZoneCorpus(
    String zoneId, {
    List<String> visibilityStatuses = const ['visible', 'review_pending'],
  }) async {
    if (zoneId.isEmpty) return const [];
    final primarySnapshot = await _firestore
        .collection('merchant_public')
        .where('zoneId', isEqualTo: zoneId)
        .where('visibilityStatus', whereIn: visibilityStatuses)
        .limit(_maxCorpus)
        .get()
        .timeout(_queryTimeout);

    if (primarySnapshot.docs.isNotEmpty || !_legacyZoneFallbackEnabled) {
      return primarySnapshot.docs
          .map(MerchantSearchItem.fromFirestore)
          .toList(growable: false);
    }

    final legacySnapshot = await _firestore
        .collection('merchant_public')
        .where('zone', isEqualTo: zoneId)
        .where('visibilityStatus', whereIn: visibilityStatuses)
        .limit(_maxCorpus)
        .get()
        .timeout(_queryTimeout);

    return legacySnapshot.docs
        .map(MerchantSearchItem.fromFirestore)
        .toList(growable: false);
  }
}
