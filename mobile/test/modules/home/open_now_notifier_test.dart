import 'package:flutter_test/flutter_test.dart';

import 'package:tum2/modules/home/analytics/open_now_analytics.dart';
import 'package:tum2/modules/home/models/open_now_models.dart';
import 'package:tum2/modules/home/providers/open_now_notifier.dart';
import 'package:tum2/modules/home/repositories/open_now_repository.dart';

void main() {
  group('OpenNowNotifier', () {
    test('prioriza verificacion y luego distancia cuando hay ubicacion',
        () async {
      final repository = _FakeOpenNowRepository(
        zones: const [
          OpenNowZone(zoneId: 'adro', name: 'Adrogue', cityId: 'banfield'),
        ],
        openNowByZone: {
          'adro': [
            _merchant(
              id: 'claimed-near',
              name: 'Claimed Cerca',
              verification: 'claimed',
              sortBoost: 90,
              lat: 0,
              lng: 0.0004,
            ),
            _merchant(
              id: 'verified-far',
              name: 'Verified Lejos',
              verification: 'verified',
              sortBoost: 20,
              lat: 0,
              lng: 0.02,
            ),
            _merchant(
              id: 'verified-near',
              name: 'Verified Cerca',
              verification: 'verified',
              sortBoost: 20,
              lat: 0,
              lng: 0.001,
            ),
          ],
        },
      );
      final analytics = _FakeOpenNowAnalytics();
      final notifier = OpenNowNotifier(
        repository: repository,
        analytics: analytics,
        locationReader: const _FakeLocationReader(
          OpenNowLocationReadResult(
            status: OpenNowLocationStatus.granted,
            position: (lat: 0.0, lng: 0.0),
          ),
        ),
      );

      await notifier.ensureInitialized();

      final ids =
          notifier.state.merchants.map((item) => item.merchantId).toList();
      expect(ids, ['verified-near', 'verified-far', 'claimed-near']);
      expect(notifier.state.merchants.first.distanceMeters, isNotNull);
      expect(analytics.resultsLoadedCount, 1);
      expect(notifier.state.hasLocation, isTrue);
    });

    test('sin ubicacion ordena por confianza y desempata alfabeticamente',
        () async {
      final repository = _FakeOpenNowRepository(
        zones: const [
          OpenNowZone(zoneId: 'adro', name: 'Adrogue', cityId: 'banfield'),
        ],
        openNowByZone: {
          'adro': [
            _merchant(
              id: 'beta',
              name: 'Beta',
              verification: 'claimed',
              sortBoost: 10,
            ),
            _merchant(
              id: 'alfa',
              name: 'Alfa',
              verification: 'claimed',
              sortBoost: 10,
            ),
          ],
        },
      );
      final analytics = _FakeOpenNowAnalytics();
      final notifier = OpenNowNotifier(
        repository: repository,
        analytics: analytics,
        locationReader: const _FakeLocationReader(
          OpenNowLocationReadResult(
            status: OpenNowLocationStatus.denied,
          ),
        ),
      );

      await notifier.ensureInitialized();

      final ids =
          notifier.state.merchants.map((item) => item.merchantId).toList();
      expect(ids, ['alfa', 'beta']);
      expect(notifier.state.hasLocation, isFalse);
      expect(analytics.resultsLoadedCount, 1);
    });

    test('si no hay abiertos muestra fallback y registra evento', () async {
      final repository = _FakeOpenNowRepository(
        zones: const [
          OpenNowZone(zoneId: 'adro', name: 'Adrogue', cityId: 'banfield'),
        ],
        openNowByZone: const {
          'adro': [],
        },
        fallbackByZone: {
          'adro': [
            _merchant(
              id: 'fallback-1',
              name: 'Abre Despues',
              verification: 'verified',
              sortBoost: 1,
              isOpenNow: false,
            ),
          ],
        },
      );
      final analytics = _FakeOpenNowAnalytics();
      final notifier = OpenNowNotifier(
        repository: repository,
        analytics: analytics,
        locationReader: const _FakeLocationReader(
          OpenNowLocationReadResult(status: OpenNowLocationStatus.unavailable),
        ),
      );

      await notifier.ensureInitialized();

      expect(notifier.state.merchants, isEmpty);
      expect(notifier.state.fallbackMerchants.length, 1);
      expect(analytics.resultsLoadedCount, 1);
    });

    test('setZone recarga resultados para la nueva zona', () async {
      final repository = _FakeOpenNowRepository(
        zones: const [
          OpenNowZone(zoneId: 'adro', name: 'Adrogue', cityId: 'banfield'),
          OpenNowZone(zoneId: 'loma', name: 'Lomas', cityId: 'banfield'),
        ],
        openNowByZone: {
          'adro': [
            _merchant(id: 'zona-adro', name: 'Adro', verification: 'verified'),
          ],
          'loma': [
            _merchant(id: 'zona-loma', name: 'Loma', verification: 'verified'),
          ],
        },
      );
      final notifier = OpenNowNotifier(
        repository: repository,
        analytics: _FakeOpenNowAnalytics(),
        locationReader: const _FakeLocationReader(
          OpenNowLocationReadResult(status: OpenNowLocationStatus.unavailable),
        ),
      );

      await notifier.ensureInitialized();
      expect(notifier.state.activeZoneId, 'adro');
      expect(notifier.state.merchants.single.merchantId, 'zona-adro');

      await notifier.setZone('loma');
      expect(notifier.state.activeZoneId, 'loma');
      expect(notifier.state.merchants.single.merchantId, 'zona-loma');
    });

    test('reutiliza cache por zona dentro del bucket y ttl', () async {
      final repository = _FakeOpenNowRepository(
        zones: const [
          OpenNowZone(zoneId: 'adro', name: 'Adrogue', cityId: 'banfield'),
          OpenNowZone(zoneId: 'loma', name: 'Lomas', cityId: 'banfield'),
        ],
        openNowByZone: {
          'adro': [
            _merchant(id: 'zona-adro', name: 'Adro', verification: 'verified'),
          ],
          'loma': [
            _merchant(id: 'zona-loma', name: 'Loma', verification: 'verified'),
          ],
        },
      );
      final notifier = OpenNowNotifier(
        repository: repository,
        analytics: _FakeOpenNowAnalytics(),
        locationReader: const _FakeLocationReader(
          OpenNowLocationReadResult(status: OpenNowLocationStatus.unavailable),
        ),
      );

      await notifier.ensureInitialized();
      await notifier.setZone('loma');
      await notifier.setZone('adro');

      expect(repository.openNowFetchCalls, 2);
      expect(notifier.state.activeZoneId, 'adro');
      expect(notifier.state.merchants.single.merchantId, 'zona-adro');
    });

    test('refresh ignora cache y vuelve a consultar', () async {
      final repository = _FakeOpenNowRepository(
        zones: const [
          OpenNowZone(zoneId: 'adro', name: 'Adrogue', cityId: 'banfield'),
        ],
        openNowByZone: {
          'adro': [
            _merchant(id: 'zona-adro', name: 'Adro', verification: 'verified'),
          ],
        },
      );
      final notifier = OpenNowNotifier(
        repository: repository,
        analytics: _FakeOpenNowAnalytics(),
        locationReader: const _FakeLocationReader(
          OpenNowLocationReadResult(status: OpenNowLocationStatus.unavailable),
        ),
      );

      await notifier.ensureInitialized();
      expect(repository.openNowFetchCalls, 1);
      await notifier.refresh();
      expect(repository.openNowFetchCalls, 2);
    });

    test(
        'incluye panadería/confitería y mantiene filtro para rubros fuera de MVP',
        () async {
      final repository = _FakeOpenNowRepository(
        zones: const [
          OpenNowZone(zoneId: 'adro', name: 'Adrogue', cityId: 'banfield'),
        ],
        openNowByZone: {
          'adro': [
            _merchant(
              id: 'out-bakery',
              name: 'Panadería Barrio',
              verification: 'verified',
              categoryId: 'panaderia',
              categoryName: 'Panadería',
            ),
            _merchant(
              id: 'ok-confiteria',
              name: 'Confitería Centro',
              verification: 'claimed',
              categoryId: 'confiteria',
              categoryName: 'Confiterías',
            ),
          ],
        },
        fallbackByZone: {
          'adro': [
            _merchant(
              id: 'out-hardware',
              name: 'Ferretería Norte',
              verification: 'verified',
              categoryId: 'hardware_store',
              categoryName: 'Ferretería',
              isOpenNow: false,
            ),
            _merchant(
              id: 'ok-kiosk',
              name: 'Kiosco Sur',
              verification: 'claimed',
              categoryId: 'kiosk',
              categoryName: 'Kioscos',
              isOpenNow: false,
            ),
          ],
        },
      );
      final notifier = OpenNowNotifier(
        repository: repository,
        analytics: _FakeOpenNowAnalytics(),
        locationReader: const _FakeLocationReader(
          OpenNowLocationReadResult(status: OpenNowLocationStatus.unavailable),
        ),
      );

      await notifier.ensureInitialized();
      expect(
        notifier.state.merchants.map((m) => m.merchantId).toList(),
        ['out-bakery', 'ok-confiteria'],
      );
      expect(notifier.state.fallbackMerchants, isEmpty);
    });
  });
}

OpenNowMerchant _merchant({
  required String id,
  required String name,
  required String verification,
  String categoryId = 'pharmacy',
  String categoryName = 'Farmacia',
  double sortBoost = 0,
  double? lat,
  double? lng,
  bool isOpenNow = true,
}) {
  return OpenNowMerchant(
    merchantId: id,
    name: name,
    categoryId: categoryId,
    categoryName: categoryName,
    zoneId: 'zone',
    addressShort: 'Direccion',
    verificationStatus: verification,
    visibilityStatus: 'visible',
    isOpenNow: isOpenNow,
    openStatusLabel: 'Abierto',
    todayScheduleLabel: 'Hoy 09:00-20:00',
    lastDataRefreshAt: DateTime.now().subtract(const Duration(minutes: 5)),
    sortBoost: sortBoost,
    lat: lat,
    lng: lng,
    isOnDutyToday: false,
  );
}

class _FakeOpenNowRepository implements OpenNowDataSource {
  _FakeOpenNowRepository({
    required this.zones,
    Map<String, List<OpenNowMerchant>>? openNowByZone,
    Map<String, List<OpenNowMerchant>>? fallbackByZone,
  })  : _openNowByZone = openNowByZone ?? const {},
        _fallbackByZone = fallbackByZone ?? const {};

  final List<OpenNowZone> zones;
  final Map<String, List<OpenNowMerchant>> _openNowByZone;
  final Map<String, List<OpenNowMerchant>> _fallbackByZone;
  int openNowFetchCalls = 0;
  int fallbackFetchCalls = 0;

  @override
  Future<List<OpenNowZone>> fetchZones() async => zones;

  @override
  Future<List<OpenNowMerchant>> fetchOpenNow({
    required String zoneId,
    int limit = 200,
  }) async {
    openNowFetchCalls++;
    final list = _openNowByZone[zoneId] ?? const [];
    return list.take(limit).toList(growable: false);
  }

  @override
  Future<List<OpenNowMerchant>> fetchFallback({
    required String zoneId,
    int limit = 40,
  }) async {
    fallbackFetchCalls++;
    final list = _fallbackByZone[zoneId] ?? const [];
    return list.take(limit).toList(growable: false);
  }
}

class _FakeLocationReader implements OpenNowLocationReader {
  const _FakeLocationReader(this.result);

  final OpenNowLocationReadResult result;

  @override
  Future<OpenNowLocationReadResult> tryGetCurrentPosition() async => result;
}

class _FakeOpenNowAnalytics implements OpenNowAnalyticsSink {
  int resultsLoadedCount = 0;
  int merchantOpenedCount = 0;

  @override
  Future<void> logOpenNowMerchantOpened({
    required String zoneId,
    required String merchantId,
    required String categoryId,
    required bool isOpenNowShown,
    required bool isOnDutyShown,
    required String source,
  }) async {
    merchantOpenedCount++;
  }

  @override
  Future<void> logOpenNowViewed({
    required String zoneId,
    required int resultsCount,
    required bool isOpenNowShown,
    required bool isOnDutyShown,
  }) async {
    resultsLoadedCount++;
  }
}
