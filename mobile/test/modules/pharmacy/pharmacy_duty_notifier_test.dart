import 'package:flutter_test/flutter_test.dart';
import 'package:tum2/modules/pharmacy/analytics/pharmacy_duty_analytics.dart';
import 'package:tum2/modules/pharmacy/models/pharmacy_duty_item.dart';
import 'package:tum2/modules/pharmacy/models/pharmacy_zone.dart';
import 'package:tum2/modules/pharmacy/providers/pharmacy_duty_notifier.dart';
import 'package:tum2/modules/pharmacy/repositories/pharmacy_duty_repository.dart';
import 'package:tum2/modules/pharmacy/repositories/zones_repository.dart';
import 'package:tum2/modules/pharmacy/services/business_date.dart';
import 'package:tum2/modules/pharmacy/services/geo_location_service.dart';
import 'package:tum2/modules/pharmacy/services/outdated_info_report_service.dart';

void main() {
  final todayKey = businessDateKey(businessTodayUtcMinus3());

  group('PharmacyDutyNotifier', () {
    test('ordena por distancia cuando hay ubicación', () async {
      final notifier = PharmacyDutyNotifier(
        dutyRepository: _FakeDutySource(
          itemsByDate: {
            todayKey: [
              const PharmacyDutyItem(
                dutyId: '1',
                merchantId: 'm-1',
                merchantName: 'Lejana',
                addressLine: 'Dir',
                phone: '1155551111',
                latitude: -34.60,
                longitude: -58.50,
                zoneId: 'z1',
                dutyDate: '2026-04-07',
                isOnDuty: true,
                isOpenNow: true,
                is24Hours: false,
                verificationStatus: 'verified',
                sortBoost: 0,
              ),
              const PharmacyDutyItem(
                dutyId: '2',
                merchantId: 'm-2',
                merchantName: 'Cercana',
                addressLine: 'Dir',
                phone: '1155552222',
                latitude: -34.60,
                longitude: -58.40,
                zoneId: 'z1',
                dutyDate: '2026-04-07',
                isOnDuty: true,
                isOpenNow: true,
                is24Hours: false,
                verificationStatus: 'verified',
                sortBoost: 0,
              ),
            ],
          },
        ),
        zonesRepository: _FakeZonesSource(),
        geoLocationService: _FakeGeoLocationService.ok(),
        analytics: _FakeAnalytics(),
      );

      await notifier.initialize();

      expect(notifier.state.items, isNotEmpty);
      expect(notifier.state.items.first.merchantId, 'm-2');
    });

    test('si falla red y hay cache previa usa cache', () async {
      final dutySource = _FakeDutySource(
        itemsByDate: {
          todayKey: [
            const PharmacyDutyItem(
              dutyId: '1',
              merchantId: 'm-1',
              merchantName: 'Farmacia',
              addressLine: 'Dir',
              phone: '1155551111',
              latitude: -34.60,
              longitude: -58.40,
              zoneId: 'z1',
              dutyDate: '2026-04-07',
              isOnDuty: true,
              isOpenNow: true,
              is24Hours: false,
              verificationStatus: 'verified',
              sortBoost: 0,
            ),
          ],
        },
      );

      final notifier = PharmacyDutyNotifier(
        dutyRepository: dutySource,
        zonesRepository: _FakeZonesSource(),
        geoLocationService: _FakeGeoLocationService.denied(),
        analytics: _FakeAnalytics(),
      );

      await notifier.initialize();
      expect(notifier.state.items.length, 1);

      dutySource.throwOnFetch = true;
      await notifier.refresh();

      expect(notifier.state.items.length, 1);
      expect(notifier.state.isUsingCachedData, isTrue);
      expect(notifier.state.errorType, PharmacyDutyErrorType.none);
    });

    test(
      'retry vuelve a inicializar cuando la zona no pudo resolverse',
      () async {
        final zonesSource = _FlakyZonesSource();
        final notifier = PharmacyDutyNotifier(
          dutyRepository: _FakeDutySource(
            itemsByDate: {
              todayKey: const [],
            },
          ),
          zonesRepository: zonesSource,
          geoLocationService: _FakeGeoLocationService.denied(),
          analytics: _FakeAnalytics(),
        );

        await notifier.initialize();
        expect(notifier.state.selectedZoneId, isEmpty);
        expect(notifier.state.errorType, PharmacyDutyErrorType.technical);

        await notifier.retry();
        expect(zonesSource.calls, 2);
        expect(notifier.state.selectedZoneId, 'z1');
        expect(notifier.state.errorType, PharmacyDutyErrorType.none);
      },
    );

    test('submitOutdatedInfoReport confirma, persiste y registra analytics',
        () async {
      final analytics = _FakeAnalytics();
      final reportService = _FakeOutdatedInfoReportService();
      final notifier = PharmacyDutyNotifier(
        dutyRepository: _FakeDutySource(
          itemsByDate: {
            todayKey: [
              const PharmacyDutyItem(
                dutyId: '1',
                merchantId: 'm-1',
                merchantName: 'Farmacia',
                addressLine: 'Dir',
                phone: '1155551111',
                latitude: -34.60,
                longitude: -58.40,
                zoneId: 'z1',
                dutyDate: '2026-04-07',
                isOnDuty: true,
                isOpenNow: true,
                is24Hours: false,
                verificationStatus: 'verified',
                sortBoost: 0,
              ),
            ],
          },
        ),
        zonesRepository: _FakeZonesSource(),
        geoLocationService: _FakeGeoLocationService.denied(),
        analytics: analytics,
        outdatedInfoReportService: reportService,
      );

      await notifier.initialize();
      final item = notifier.state.items.first;
      final status = await notifier.submitOutdatedInfoReport(
        item: item,
        reasonCode: 'wrong_schedule',
      );

      expect(status, OutdatedInfoReportSubmitStatus.created);
      expect(reportService.calls, 1);
      expect(analytics.outdatedInfoConfirmedCount, 1);
      expect(analytics.outdatedInfoSubmittedCount, 1);
    });
  });
}

class _FakeDutySource implements PharmacyDutySource {
  _FakeDutySource({
    required this.itemsByDate,
  });

  final Map<String, List<PharmacyDutyItem>> itemsByDate;
  bool throwOnFetch = false;

  @override
  Future<List<PharmacyDutyItem>> getPublishedDuties({
    required String zoneId,
    required String dateKey,
  }) async {
    if (throwOnFetch) throw Exception('network');
    return itemsByDate[dateKey] ?? const [];
  }
}

class _FakeZonesSource implements ZonesSource {
  @override
  Future<List<PharmacyZone>> getActiveZones() async {
    return const [
      PharmacyZone(
        zoneId: 'z1',
        name: 'Centro',
        cityId: 'caba',
        centroidLat: -34.6037,
        centroidLng: -58.3816,
      ),
    ];
  }
}

class _FlakyZonesSource implements ZonesSource {
  int calls = 0;

  @override
  Future<List<PharmacyZone>> getActiveZones() async {
    calls++;
    if (calls == 1) {
      throw Exception('temporary zones error');
    }
    return const [
      PharmacyZone(
        zoneId: 'z1',
        name: 'Centro',
        cityId: 'caba',
        centroidLat: -34.6037,
        centroidLng: -58.3816,
      ),
    ];
  }
}

class _FakeGeoLocationService extends GeoLocationService {
  _FakeGeoLocationService.ok()
      : _result = GeoPositionOk(lat: -34.6037, lng: -58.3816);
  _FakeGeoLocationService.denied() : _result = GeoPositionDenied();

  final GeoPositionResult _result;

  @override
  Future<GeoPositionResult> getPosition() async => _result;
}

class _FakeAnalytics implements PharmacyDutyAnalyticsSink {
  int outdatedInfoConfirmedCount = 0;
  int outdatedInfoSubmittedCount = 0;

  @override
  Future<void> logOutdatedInfoConfirmed({
    required String zoneId,
    required String merchantId,
    required String source,
    required String reasonCode,
  }) async {
    outdatedInfoConfirmedCount++;
  }

  @override
  Future<void> logOutdatedInfoReportSubmitted({
    required String zoneId,
    required String merchantId,
    required String source,
    required String reasonCode,
  }) async {
    outdatedInfoSubmittedCount++;
  }

  @override
  Future<void> logOutdatedInfoTapped({
    required String zoneId,
    required String merchantId,
    required String source,
  }) async {}

  @override
  Future<void> logPharmacyDutyDetailOpened({
    required String zoneId,
    required String merchantId,
    required String source,
  }) async {}

  @override
  Future<void> logPharmacyDutyListViewed({
    required String zoneId,
    required int resultsCount,
    required bool isOpenNowShown,
    required bool isOnDutyShown,
  }) async {}

  @override
  Future<void> logPharmacyDutyUsefulActionClicked({
    required String zoneId,
    required String merchantId,
    required String actionType,
    required String distanceBucket,
    required String source,
  }) async {}
}

class _FakeOutdatedInfoReportService implements OutdatedInfoReportService {
  int calls = 0;

  @override
  Future<OutdatedInfoReportSubmitStatus> submit({
    required String merchantId,
    required String zoneId,
    required String reasonCode,
    required String source,
    required String dateKey,
  }) async {
    calls++;
    return OutdatedInfoReportSubmitStatus.created;
  }
}
