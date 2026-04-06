import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dtos/merchant_detail_dto.dart';

abstract interface class MerchantDetailDataSource {
  Future<MerchantCoreDto?> fetchCore(String merchantId);

  Future<List<MerchantProductDto>> fetchProducts(
    String merchantId, {
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
  Future<MerchantCoreDto?> fetchCore(String merchantId) async {
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
  Future<List<MerchantProductDto>> fetchProducts(
    String merchantId, {
    int limit = 6,
  }) async {
    final snapshot = await _firestore
        .collection('merchant_products')
        .where('merchantId', isEqualTo: merchantId)
        .where('visibilityStatus', isEqualTo: 'visible')
        .limit(limit)
        .get()
        .timeout(_secondaryTimeout);

    return snapshot.docs
        .map(MerchantProductDto.fromDocument)
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
