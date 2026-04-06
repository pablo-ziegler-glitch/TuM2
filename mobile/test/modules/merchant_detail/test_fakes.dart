import 'dart:async';

import 'package:tum2/modules/merchant_detail/analytics/merchant_detail_analytics.dart';
import 'package:tum2/modules/merchant_detail/application/merchant_location_reader.dart';
import 'package:tum2/modules/merchant_detail/data/dtos/merchant_detail_dto.dart';
import 'package:tum2/modules/merchant_detail/data/merchant_detail_repository.dart';
import 'package:tum2/modules/merchant_detail/domain/merchant_maps.dart';

class FakeMerchantDetailRepository implements MerchantDetailDataSource {
  Future<MerchantCoreDto?> Function(String merchantId)? fetchCoreHandler;
  Future<List<MerchantProductDto>> Function(String merchantId, int limit)?
      fetchProductsHandler;
  Future<MerchantScheduleDto?> Function(String merchantId)?
      fetchScheduleHandler;
  Future<MerchantOperationalSignalsDto?> Function(String merchantId)?
      fetchSignalsHandler;

  @override
  Future<MerchantCoreDto?> fetchCore(String merchantId) {
    final handler = fetchCoreHandler;
    if (handler == null) return Future.value(null);
    return handler(merchantId);
  }

  @override
  Future<List<MerchantProductDto>> fetchProducts(
    String merchantId, {
    int limit = 6,
  }) {
    final handler = fetchProductsHandler;
    if (handler == null) return Future.value(const []);
    return handler(merchantId, limit);
  }

  @override
  Future<MerchantScheduleDto?> fetchSchedule(String merchantId) {
    final handler = fetchScheduleHandler;
    if (handler == null) return Future.value(null);
    return handler(merchantId);
  }

  @override
  Future<MerchantOperationalSignalsDto?> fetchSignals(String merchantId) {
    final handler = fetchSignalsHandler;
    if (handler == null) return Future.value(null);
    return handler(merchantId);
  }
}

class RecordingMerchantDetailAnalytics implements MerchantDetailAnalyticsSink {
  final List<Map<String, Object>> openedEvents = [];
  final List<Map<String, Object>> directionsEvents = [];
  final List<Map<String, Object>> productEvents = [];
  final List<Map<String, Object>> scheduleEvents = [];
  final List<Map<String, Object>> secondaryErrorEvents = [];

  @override
  Future<void> logDetailOpened({
    required String merchantId,
    required String verificationStatus,
  }) async {
    openedEvents.add({
      'merchantId': merchantId,
      'verificationStatus': verificationStatus,
    });
  }

  @override
  Future<void> logDirectionsTapped({
    required String merchantId,
    required bool usedCoordinates,
    required bool launchSucceeded,
  }) async {
    directionsEvents.add({
      'merchantId': merchantId,
      'usedCoordinates': usedCoordinates,
      'launchSucceeded': launchSucceeded,
    });
  }

  @override
  Future<void> logProductTapped({
    required String merchantId,
    required String productId,
  }) async {
    productEvents.add({
      'merchantId': merchantId,
      'productId': productId,
    });
  }

  @override
  Future<void> logScheduleExpanded({
    required String merchantId,
    required bool expanded,
  }) async {
    scheduleEvents.add({
      'merchantId': merchantId,
      'expanded': expanded,
    });
  }

  @override
  Future<void> logSecondaryLoadFailed({
    required String merchantId,
    required String section,
  }) async {
    secondaryErrorEvents.add({
      'merchantId': merchantId,
      'section': section,
    });
  }
}

class RecordingMapsLauncher implements MerchantMapsLauncher {
  RecordingMapsLauncher({this.openResult = true});

  final bool openResult;
  int callCount = 0;
  MerchantMapsIntent? lastIntent;

  @override
  Future<bool> open(MerchantMapsIntent intent) async {
    callCount += 1;
    lastIntent = intent;
    return openResult;
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
  String verificationStatus = 'verified',
  String visibilityStatus = 'visible',
  bool? isOpenNow = true,
  bool hasPharmacyDutyToday = false,
  String openStatusLabel = 'Hoy: 09:00-20:00',
  String address = 'Av. Corrientes 1234',
  double lat = -34.6037,
  double lng = -58.3816,
  Map<String, dynamic>? operationalSignals,
}) {
  return MerchantCoreDto(
    id: id,
    data: {
      'merchantId': id,
      'name': name,
      'categoryId': categoryId,
      'categoryLabel': categoryLabel,
      'verificationStatus': verificationStatus,
      'visibilityStatus': visibilityStatus,
      'isOpenNow': isOpenNow,
      'hasPharmacyDutyToday': hasPharmacyDutyToday,
      'openStatusLabel': openStatusLabel,
      'address': address,
      'lat': lat,
      'lng': lng,
      if (operationalSignals != null) 'operationalSignals': operationalSignals,
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

Future<T> delayResult<T>(Duration duration, T value) async {
  await Future<void>.delayed(duration);
  return value;
}
