import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../pharmacy/services/distance_calculator.dart';
import 'dtos/merchant_detail_dto.dart';

abstract interface class MerchantDetailDataSource {
  Future<MerchantCoreDto?> fetchMerchantPublic(String merchantId);

  Future<PharmacyDutyDto?> fetchActivePharmacyDuty(String merchantId);

  Future<List<MerchantProductDto>> fetchFeaturedProducts(
    String merchantId, {
    List<String> preferredProductIds = const [],
    int limit = 6,
  });

  Future<MerchantScheduleDto?> fetchSchedule(String merchantId);

  Future<MerchantOperationalSignalsDto?> fetchSignals(String merchantId);
}

class MerchantDetailRepository implements MerchantDetailDataSource {
  MerchantDetailRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const Duration _coreTimeout = Duration(seconds: 5);
  static const Duration _secondaryTimeout = Duration(seconds: 4);

  @override
  Future<MerchantCoreDto?> fetchMerchantPublic(String merchantId) async {
    final snapshot = await _firestore
        .doc('merchant_public/$merchantId')
        .get()
        .timeout(_coreTimeout);

    if (!snapshot.exists) return null;

    final data = snapshot.data() ?? const <String, dynamic>{};
    final visibilityStatus =
        (data['visibilityStatus'] as String?)?.trim().toLowerCase() ?? '';
    if (visibilityStatus != 'visible') {
      return null;
    }

    return MerchantCoreDto.fromDocument(snapshot);
  }

  @override
  Future<PharmacyDutyDto?> fetchActivePharmacyDuty(String merchantId) async {
    final today = todayArgentina();
    final snapshot = await _firestore
        .collection('pharmacy_duties')
        .where('merchantId', isEqualTo: merchantId)
        .where('status', isEqualTo: 'published')
        .where('date', isEqualTo: today)
        .limit(3)
        .get()
        .timeout(_secondaryTimeout);

    if (snapshot.docs.isEmpty) return null;

    final now = DateTime.now().toLocal();
    QueryDocumentSnapshot<Map<String, dynamic>>? activeDuty;
    for (final doc in snapshot.docs) {
      final rawEndsAt = doc.data()['endsAt'];
      if (rawEndsAt is Timestamp) {
        final endsAt = rawEndsAt.toDate().toLocal();
        if (endsAt.isAfter(now)) {
          activeDuty = doc;
          break;
        }
      } else {
        activeDuty = doc;
        break;
      }
    }

    return PharmacyDutyDto.fromDocument(activeDuty ?? snapshot.docs.first);
  }

  @override
  Future<List<MerchantProductDto>> fetchFeaturedProducts(
    String merchantId, {
    List<String> preferredProductIds = const [],
    int limit = 6,
  }) async {
    final cleanedIds = preferredProductIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .take(10)
        .toList(growable: false);

    if (cleanedIds.isNotEmpty) {
      final byIdsSnapshot = await _firestore
          .collection('merchant_products')
          .where(FieldPath.documentId, whereIn: cleanedIds)
          .get()
          .timeout(_secondaryTimeout);

      final byIdOrdered = <String, MerchantProductDto>{};
      for (final doc in byIdsSnapshot.docs) {
        final data = doc.data();
        final visibilityStatus =
            (data['visibilityStatus'] as String?)?.trim().toLowerCase();
        final docMerchantId = (data['merchantId'] as String?)?.trim();
        if (docMerchantId != merchantId) continue;
        if (visibilityStatus == 'hidden' || visibilityStatus == 'archived') {
          continue;
        }
        byIdOrdered[doc.id] = MerchantProductDto.fromDocument(doc);
      }

      final ordered = cleanedIds
          .where(byIdOrdered.containsKey)
          .map((id) => byIdOrdered[id]!)
          .take(limit)
          .toList(growable: false);
      if (ordered.isNotEmpty) return ordered;
    }

    final snapshot = await _firestore
        .collection('merchant_products')
        .where('merchantId', isEqualTo: merchantId)
        .where('visibilityStatus', isEqualTo: 'visible')
        .limit(limit)
        .get()
        .timeout(_secondaryTimeout);

    return snapshot.docs
        .map(MerchantProductDto.fromDocument)
        .where((dto) {
          final visibility =
              (dto.data['visibilityStatus'] as String?)?.trim().toLowerCase();
          return visibility != 'hidden' && visibility != 'archived';
        })
        .take(limit)
        .toList(growable: false);
  }

  @override
  Future<MerchantScheduleDto?> fetchSchedule(String merchantId) async {
    final snapshot = await _firestore
        .doc('merchant_schedules/$merchantId')
        .get()
        .timeout(_secondaryTimeout);
    if (!snapshot.exists) return null;
    return MerchantScheduleDto.fromDocument(snapshot);
  }

  @override
  Future<MerchantOperationalSignalsDto?> fetchSignals(String merchantId) async {
    final snapshot = await _firestore
        .doc('merchant_operational_signals/$merchantId')
        .get()
        .timeout(_secondaryTimeout);
    if (!snapshot.exists) return null;
    return MerchantOperationalSignalsDto.fromDocument(snapshot);
  }
}

final merchantDetailRepositoryProvider = Provider<MerchantDetailDataSource>(
  (ref) => MerchantDetailRepository(),
);
