import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tum2/modules/merchant_detail/analytics/merchant_detail_analytics.dart';
import 'package:tum2/modules/merchant_detail/application/merchant_detail_actions.dart';
import 'package:tum2/modules/merchant_detail/application/merchant_location_reader.dart';
import 'package:tum2/modules/merchant_detail/data/dtos/merchant_detail_dto.dart';
import 'package:tum2/modules/merchant_detail/data/merchant_detail_repository.dart';

class FakeMerchantDetailRepository implements MerchantDetailDataSource {
  Future<MerchantCoreDto?> Function(String merchantId)? fetchCoreHandler;
  Future<PharmacyDutyDto?> Function(String merchantId)? fetchDutyHandler;
  Future<List<MerchantProductDto>> Function(
    String merchantId,
    List<String> preferredProductIds,
    int limit,
  )? fetchProductsHandler;
  Future<MerchantScheduleDto?> Function(String merchantId)?
      fetchScheduleHandler;
  Future<MerchantOperationalSignalsDto?> Function(String merchantId)?
      fetchSignalsHandler;

  @override
  Future<MerchantCoreDto?> fetchMerchantPublic(String merchantId) {
    final handler = fetchCoreHandler;
    if (handler == null) return Future.value(null);
    return handler(merchantId);
  }

  @override
  Future<PharmacyDutyDto?> fetchActivePharmacyDuty(String merchantId) {
    final handler = fetchDutyHandler;
    if (handler == null) return Future.value(null);
    return handler(merchantId);
  }

  @override
  Future<List<MerchantProductDto>> fetchFeaturedProducts(
    String merchantId, {
    List<String> preferredProductIds = const [],
    int limit = 6,
  }) {
    final handler = fetchProductsHandler;
    if (handler == null) return Future.value(const []);
    return handler(merchantId, preferredProductIds, limit);
  }

  @override
  Future<MerchantScheduleDto?> fetchSchedule(String merchantId) {
    final handler = fetchScheduleHandler;
    if (handler == null) return Future.value(null);
    return handler(merchantId);
  }

  Future<MerchantOperationalSignalsDto?> fetchSignals(String merchantId) {
    final handler = fetchSignalsHandler;
    if (handler == null) return Future.value(null);
    return handler(merchantId);
  }
}

class RecordingMerchantDetailAnalytics implements MerchantDetailAnalyticsSink {
  final List<Map<String, Object>> detailViewEvents = [];
  final List<Map<String, Object>> callEvents = [];
  final List<Map<String, Object>> directionsEvents = [];
  final List<Map<String, Object>> whatsappEvents = [];
  final List<Map<String, Object>> shareEvents = [];
  final List<Map<String, Object>> dutyBannerEvents = [];
  final List<Map<String, Object>> errorEvents = [];

  @override
  Future<void> logDetailOpened({
    required String merchantId,
    required String zoneId,
    required String categoryId,
    required bool hasPharmacyDutyToday,
    required String source,
  }) async {
    detailViewEvents.add({
      'merchantId': merchantId,
      'zoneId': zoneId,
      'categoryId': categoryId,
      'hasPharmacyDutyToday': hasPharmacyDutyToday,
      'source': source,
    });
  }

  @override
  Future<void> logCallClick({
    required String merchantId,
    required String zoneId,
    required String categoryId,
    required String source,
    required bool launchSucceeded,
  }) async {
    callEvents.add({
      'merchantId': merchantId,
      'zoneId': zoneId,
      'categoryId': categoryId,
      'source': source,
      'launchSucceeded': launchSucceeded,
    });
  }

  @override
  Future<void> logDirectionsClick({
    required String merchantId,
    required String zoneId,
    required String categoryId,
    required String source,
    required bool launchSucceeded,
  }) async {
    directionsEvents.add({
      'merchantId': merchantId,
      'zoneId': zoneId,
      'categoryId': categoryId,
      'source': source,
      'launchSucceeded': launchSucceeded,
    });
  }

  @override
  Future<void> logWhatsAppClick({
    required String merchantId,
    required String zoneId,
    required String categoryId,
    required String source,
    required bool launchSucceeded,
  }) async {
    whatsappEvents.add({
      'merchantId': merchantId,
      'zoneId': zoneId,
      'categoryId': categoryId,
      'source': source,
      'launchSucceeded': launchSucceeded,
    });
  }

  @override
  Future<void> logShareClick({
    required bool launchSucceeded,
  }) async {
    shareEvents.add({
      'launchSucceeded': launchSucceeded,
    });
  }

  @override
  Future<void> logDutyBannerView({
    required bool hasEndsAt,
  }) async {
    dutyBannerEvents.add({
      'hasEndsAt': hasEndsAt,
    });
  }

  @override
  Future<void> logError({
    required String stage,
    required String errorType,
  }) async {
    errorEvents.add({
      'stage': stage,
      'errorType': errorType,
    });
  }
}

class FakeMerchantDetailActions implements MerchantDetailActions {
  FakeMerchantDetailActions({
    this.callResult = true,
    this.whatsAppResult = true,
    this.directionsResult = true,
    this.shareResult = true,
  });

  bool callResult;
  bool whatsAppResult;
  bool directionsResult;
  bool shareResult;
  int callCount = 0;
  int whatsappCount = 0;
  int directionsCount = 0;
  int shareCount = 0;

  @override
  Future<bool> openCall(String phone) async {
    callCount += 1;
    return callResult;
  }

  @override
  Future<bool> openWhatsApp(String phone) async {
    whatsappCount += 1;
    return whatsAppResult;
  }

  @override
  Future<bool> openDirections({
    required String address,
    double? lat,
    double? lng,
    String? mapsUrl,
  }) async {
    directionsCount += 1;
    return directionsResult;
  }

  @override
  Future<bool> shareMerchant({
    required String merchantId,
    required String merchantName,
  }) async {
    shareCount += 1;
    return shareResult;
  }
}

class FakeLocationReader implements MerchantLocationReader {
  FakeLocationReader(this.result);

  MerchantUserLocation? result;

  @override
  Future<MerchantUserLocation?> getCurrentLocationIfPermitted() async {
    return result;
  }
}

MerchantCoreDto buildCoreDto({
  String id = 'merchant-1',
  String name = 'Farmacia Central',
  String categoryId = 'pharmacy',
  String categoryLabel = 'Farmacias',
  String visibilityStatus = 'visible',
  bool? isOpenNow = true,
  bool hasPharmacyDutyToday = false,
  String openStatusLabel = 'Hoy: 09:00-20:00',
  String address = 'Av. Corrientes 1234',
  String? phonePrimary = '+54 11 4444-5555',
  double lat = -34.6037,
  double lng = -58.3816,
  List<String> featuredProductIds = const ['product-1'],
  Timestamp? lastDataRefreshAt,
}) {
  return MerchantCoreDto(
    id: id,
    data: {
      'merchantId': id,
      'name': name,
      'categoryId': categoryId,
      'categoryLabel': categoryLabel,
      'visibilityStatus': visibilityStatus,
      'isOpenNow': isOpenNow,
      'hasPharmacyDutyToday': hasPharmacyDutyToday,
      'openStatusLabel': openStatusLabel,
      'address': address,
      'phonePrimary': phonePrimary,
      'lat': lat,
      'lng': lng,
      'featuredProductIds': featuredProductIds,
      'lastDataRefreshAt':
          lastDataRefreshAt ?? Timestamp.fromDate(DateTime(2026, 4, 7, 12)),
    },
  );
}

PharmacyDutyDto buildDutyDto({
  String id = 'duty-1',
  DateTime? endsAt,
}) {
  return PharmacyDutyDto(
    id: id,
    data: {
      'merchantId': 'merchant-1',
      if (endsAt != null) 'endsAt': Timestamp.fromDate(endsAt),
    },
  );
}

MerchantProductDto buildProductDto({
  String id = 'product-1',
  String merchantId = 'merchant-1',
  String name = 'Ibuprofeno 400',
  String priceLabel = '\$2500',
}) {
  return MerchantProductDto(
    id: id,
    data: {
      'merchantId': merchantId,
      'name': name,
      'priceLabel': priceLabel,
      'visibilityStatus': 'visible',
    },
  );
}

MerchantScheduleDto buildScheduleDto({
  String id = 'merchant-1',
}) {
  return MerchantScheduleDto(
    id: id,
    data: {
      'merchantId': id,
      'timezone': 'America/Argentina/Buenos_Aires',
      'weeklySchedule': {
        'monday': {'open': '09:00', 'close': '20:00'},
        'tuesday': {'open': '09:00', 'close': '20:00'},
      },
    },
  );
}

MerchantOperationalSignalsDto buildSignalsDto({
  String id = 'merchant-1',
}) {
  return MerchantOperationalSignalsDto(
    id: id,
    data: {
      'merchantId': id,
      'signals': {
        'hasDelivery': true,
      },
    },
  );
}
