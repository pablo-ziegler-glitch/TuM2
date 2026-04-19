import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/pharmacy_duty_item.dart';

class PharmacyDutyRecord {
  const PharmacyDutyRecord({
    required this.id,
    required this.merchantId,
    required this.zoneId,
    required this.date,
  });

  final String id;
  final String merchantId;
  final String zoneId;
  final String date;
}

class MerchantPublicRecord {
  const MerchantPublicRecord({
    required this.id,
    required this.data,
  });

  final String id;
  final Map<String, dynamic> data;
}

abstract interface class PharmacyDutyDataSource {
  Future<List<PharmacyDutyRecord>> fetchPublishedDuties({
    required String zoneId,
    required String dateKey,
  });

  Future<List<MerchantPublicRecord>> fetchMerchantsByIds(List<String> ids);
}

class FirestorePharmacyDutyDataSource implements PharmacyDutyDataSource {
  FirestorePharmacyDutyDataSource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  static const Duration _timeout = Duration(seconds: 6);
  static const int _maxDutyDocsPerQuery = 120;

  @override
  Future<List<PharmacyDutyRecord>> fetchPublishedDuties({
    required String zoneId,
    required String dateKey,
  }) async {
    final snap = await _firestore
        .collection('pharmacy_duties')
        .where('zoneId', isEqualTo: zoneId)
        .where('date', isEqualTo: dateKey)
        .where('status', isEqualTo: 'published')
        .limit(_maxDutyDocsPerQuery)
        .get()
        .timeout(_timeout);
    return snap.docs
        .map((doc) => PharmacyDutyRecord(
              id: doc.id,
              merchantId: (doc.data()['merchantId'] as String?)?.trim() ?? '',
              zoneId: (doc.data()['zoneId'] as String?)?.trim() ?? zoneId,
              date: (doc.data()['date'] as String?)?.trim() ?? dateKey,
            ))
        .where((record) => record.merchantId.isNotEmpty)
        .toList();
  }

  @override
  Future<List<MerchantPublicRecord>> fetchMerchantsByIds(
      List<String> ids) async {
    if (ids.isEmpty) return const [];
    final chunks = PharmacyDutyRepository.chunkIds(ids);
    final all = <MerchantPublicRecord>[];
    for (final chunk in chunks) {
      final snap = await _firestore
          .collection('merchant_public')
          .where(FieldPath.documentId, whereIn: chunk)
          .get()
          .timeout(_timeout);
      all.addAll(
        snap.docs.map(
          (doc) => MerchantPublicRecord(id: doc.id, data: doc.data()),
        ),
      );
    }
    return all;
  }
}

class PharmacyDutyInconsistency {
  const PharmacyDutyInconsistency({
    required this.code,
    required this.merchantId,
    required this.zoneId,
    required this.dateKey,
    this.extra = const {},
  });

  final String code;
  final String merchantId;
  final String zoneId;
  final String dateKey;
  final Map<String, Object?> extra;
}

abstract interface class PharmacyDutyInconsistencyLogger {
  void log(PharmacyDutyInconsistency inconsistency);
}

class ConsolePharmacyDutyInconsistencyLogger
    implements PharmacyDutyInconsistencyLogger {
  @override
  void log(PharmacyDutyInconsistency inconsistency) {
    developer.log(
      'pharmacy_duty_inconsistency',
      name: 'PharmacyDutyRepository',
      error: {
        'code': inconsistency.code,
        'merchantId': inconsistency.merchantId,
        'zoneId': inconsistency.zoneId,
        'date': inconsistency.dateKey,
        ...inconsistency.extra,
      },
    );
  }
}

class PharmacyDutyRepository implements PharmacyDutySource {
  PharmacyDutyRepository({
    PharmacyDutyDataSource? dataSource,
    PharmacyDutyInconsistencyLogger? inconsistencyLogger,
  })  : _dataSource = dataSource ?? FirestorePharmacyDutyDataSource(),
        _inconsistencyLogger =
            inconsistencyLogger ?? ConsolePharmacyDutyInconsistencyLogger();

  final PharmacyDutyDataSource _dataSource;
  final PharmacyDutyInconsistencyLogger _inconsistencyLogger;

  @override
  Future<List<PharmacyDutyItem>> getPublishedDuties({
    required String zoneId,
    required String dateKey,
  }) async {
    final duties = await _dataSource.fetchPublishedDuties(
      zoneId: zoneId,
      dateKey: dateKey,
    );
    if (duties.isEmpty) return const [];

    final deduped = <String, PharmacyDutyRecord>{};
    for (final duty in duties) {
      if (deduped.containsKey(duty.merchantId)) {
        _logInconsistency(
          code: 'duplicate_duty_published',
          merchantId: duty.merchantId,
          zoneId: zoneId,
          dateKey: dateKey,
        );
        continue;
      }
      deduped[duty.merchantId] = duty;
    }
    if (deduped.isEmpty) return const [];

    final merchants = await _dataSource
        .fetchMerchantsByIds(deduped.keys.toList(growable: false));
    final merchantsById = {for (final m in merchants) m.id: m.data};

    final items = <PharmacyDutyItem>[];
    for (final duty in deduped.values) {
      final merchant = merchantsById[duty.merchantId];
      if (merchant == null) {
        _logInconsistency(
          code: 'missing_merchant_public',
          merchantId: duty.merchantId,
          zoneId: zoneId,
          dateKey: dateKey,
        );
        continue;
      }

      final visibility = (merchant['visibilityStatus'] as String?) ?? '';
      if (visibility != 'visible') {
        _logInconsistency(
          code: 'merchant_not_visible',
          merchantId: duty.merchantId,
          zoneId: zoneId,
          dateKey: dateKey,
          extra: {'visibilityStatus': visibility},
        );
        continue;
      }

      final categoryId = (merchant['categoryId'] as String?)?.trim();
      if (!_isPharmacyCategory(categoryId)) {
        _logInconsistency(
          code: 'merchant_category_mismatch',
          merchantId: duty.merchantId,
          zoneId: zoneId,
          dateKey: dateKey,
          extra: {'categoryId': categoryId},
        );
        continue;
      }

      final phone = (merchant['phone'] as String?)?.trim();
      final name = (merchant['name'] as String?)?.trim() ?? '';
      final addressLine = (merchant['addressLine'] as String?)?.trim() ?? '';
      final geo = _extractGeo(merchant);
      final canCall = PharmacyDutyItem.isValidPhone(phone);
      final canNavigate = geo != null;

      if (name.isEmpty || (!canCall && !canNavigate)) {
        _logInconsistency(
          code: 'missing_critical_fields',
          merchantId: duty.merchantId,
          zoneId: zoneId,
          dateKey: dateKey,
          extra: {
            'hasName': name.isNotEmpty,
            'hasPhone': canCall,
            'hasGeo': canNavigate,
          },
        );
        continue;
      }

      final merchantZoneId = (merchant['zoneId'] as String?)?.trim();
      if (merchantZoneId != null &&
          merchantZoneId.isNotEmpty &&
          merchantZoneId != duty.zoneId) {
        _logInconsistency(
          code: 'zone_mismatch',
          merchantId: duty.merchantId,
          zoneId: zoneId,
          dateKey: dateKey,
          extra: {'merchantZoneId': merchantZoneId, 'dutyZoneId': duty.zoneId},
        );
      }

      items.add(
        PharmacyDutyItem(
          dutyId: duty.id,
          merchantId: duty.merchantId,
          merchantName: name,
          addressLine: addressLine,
          phone: phone,
          latitude: geo?.$1,
          longitude: geo?.$2,
          zoneId: duty.zoneId,
          dutyDate: duty.date,
          isOnDuty: true,
          isOpenNow: merchant['isOpenNow'] == true,
          is24Hours: merchant['is24h'] == true || merchant['is24Hours'] == true,
          verificationStatus:
              (merchant['verificationStatus'] as String?) ?? 'unverified',
          sortBoost: (merchant['sortBoost'] as num?)?.toInt() ?? 0,
        ),
      );
    }
    return items;
  }

  static List<List<String>> chunkIds(List<String> ids, {int chunkSize = 10}) {
    if (ids.isEmpty) return const [];
    final chunks = <List<String>>[];
    for (var i = 0; i < ids.length; i += chunkSize) {
      final end = (i + chunkSize < ids.length) ? i + chunkSize : ids.length;
      chunks.add(ids.sublist(i, end));
    }
    return chunks;
  }

  void _logInconsistency({
    required String code,
    required String merchantId,
    required String zoneId,
    required String dateKey,
    Map<String, Object?> extra = const {},
  }) {
    _inconsistencyLogger.log(
      PharmacyDutyInconsistency(
        code: code,
        merchantId: merchantId,
        zoneId: zoneId,
        dateKey: dateKey,
        extra: extra,
      ),
    );
  }
}

abstract interface class PharmacyDutySource {
  Future<List<PharmacyDutyItem>> getPublishedDuties({
    required String zoneId,
    required String dateKey,
  });
}

bool _isPharmacyCategory(String? categoryId) {
  if (categoryId == null || categoryId.isEmpty) return true;
  final normalized = categoryId.toLowerCase();
  return normalized.contains('farmacia') || normalized.contains('pharmacy');
}

(double, double)? _extractGeo(Map<String, dynamic> merchantData) {
  final geoRaw = merchantData['geo'];
  if (geoRaw is GeoPoint) {
    return (geoRaw.latitude, geoRaw.longitude);
  }
  if (geoRaw is Map<String, dynamic>) {
    final lat = (geoRaw['lat'] as num?)?.toDouble();
    final lng = (geoRaw['lng'] as num?)?.toDouble();
    if (lat != null && lng != null) return (lat, lng);
  }
  final lat = (merchantData['lat'] as num?)?.toDouble();
  final lng = (merchantData['lng'] as num?)?.toDouble();
  if (lat != null && lng != null) return (lat, lng);
  return null;
}
