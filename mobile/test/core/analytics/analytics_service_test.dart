import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tum2/core/analytics/analytics_backend.dart';
import 'package:tum2/core/analytics/analytics_service.dart';
import 'package:tum2/core/firebase/app_environment.dart';

class _FakeBackend implements AnalyticsBackend {
  final events = <({String name, Map<String, Object> parameters})>[];
  bool throwOnLog = false;

  @override
  Future<void> logEvent({
    required String name,
    required Map<String, Object> parameters,
  }) async {
    if (throwOnLog) throw Exception('network');
    events.add((name: name, parameters: parameters));
  }

  @override
  Future<void> setUserProperty({
    required String name,
    required String? value,
  }) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AnalyticsService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('sanitiza PII y enums inválidos', () async {
      final backend = _FakeBackend();
      final service = AnalyticsService(
        backend: backend,
        environment: AppEnvironment.prod,
        isWeb: false,
        isWebConsentGranted: () => true,
        preferencesLoader: SharedPreferences.getInstance,
      );

      await service.track(
        event: 'pharmacy_duty_feedback_positive',
        parameters: {
          'copy_variant': 'seasonal_messirve',
          'email': 'test@tum2.app',
          'phone': '+5491133334444',
          'query': 'farmacia abierta',
          'distance_bucket': 'bad_bucket',
        },
      );

      expect(backend.events.length, 1);
      final params = backend.events.single.parameters;
      expect(params['copy_variant'], 'seasonal_messirve');
      expect(params.containsKey('email'), isFalse);
      expect(params.containsKey('phone'), isFalse);
      expect(params.containsKey('query'), isFalse);
      expect(params.containsKey('distance_bucket'), isFalse);
    });

    test('bloquea eventos fuera de la taxonomia oficial', () async {
      final backend = _FakeBackend();
      final service = AnalyticsService(
        backend: backend,
        environment: AppEnvironment.prod,
        isWeb: false,
        isWebConsentGranted: () => true,
        preferencesLoader: SharedPreferences.getInstance,
      );

      await service.track(
        event: 'internal_debug_event',
        parameters: {'surface': 'search_results'},
      );

      expect(backend.events, isEmpty);
    });

    test('descarta claves fuera de contrato y fragmentos sensibles', () async {
      final backend = _FakeBackend();
      final service = AnalyticsService(
        backend: backend,
        environment: AppEnvironment.prod,
        isWeb: false,
        isWebConsentGranted: () => true,
        preferencesLoader: SharedPreferences.getInstance,
      );

      await service.track(
        event: 'report_submitted',
        parameters: {
          'surface': 'pharmacy_duty',
          'active_zone_id': 'z1',
          'entity_zone_id': 'z2',
          'reason_code': 'wrong_schedule',
          'user_email_hint': 'x@y.com',
          'custom_payload': 'abc',
          'attachment': 'https://storage.example/file.jpg',
        },
      );

      expect(backend.events.length, 1);
      final params = backend.events.single.parameters;
      expect(params['surface'], 'pharmacy_duty');
      expect(params['active_zone_id'], 'z1');
      expect(params['entity_zone_id'], 'z2');
      expect(params.containsKey('user_email_hint'), isFalse);
      expect(params.containsKey('custom_payload'), isFalse);
      expect(params.containsKey('attachment'), isFalse);
    });

    test('bloquea identificadores directos de entidad', () async {
      final backend = _FakeBackend();
      final service = AnalyticsService(
        backend: backend,
        environment: AppEnvironment.prod,
        isWeb: false,
        isWebConsentGranted: () => true,
        preferencesLoader: SharedPreferences.getInstance,
      );

      await service.track(
        event: 'owner_dashboard_viewed',
        parameters: {
          'merchant_id': 'm-123',
          'product_id': 'p-999',
          'merchant_ref': 'legacy-ref',
          'source': 'owner',
        },
      );

      expect(backend.events.length, 1);
      final params = backend.events.single.parameters;
      expect(params['source'], 'owner');
      expect(params.containsKey('merchant_id'), isFalse);
      expect(params.containsKey('product_id'), isFalse);
      expect(params.containsKey('merchant_ref'), isFalse);
    });

    test('dedupe evita doble emisión inmediata', () async {
      final backend = _FakeBackend();
      final service = AnalyticsService(
        backend: backend,
        environment: AppEnvironment.prod,
        isWeb: false,
        isWebConsentGranted: () => true,
        preferencesLoader: SharedPreferences.getInstance,
      );

      await service
          .track(event: 'map_viewed', parameters: {'surface': 'search_map'});
      await service
          .track(event: 'map_viewed', parameters: {'surface': 'search_map'});

      expect(backend.events.length, 1);
    });

    test('dev/staging no emite analytics real', () async {
      final backend = _FakeBackend();
      final service = AnalyticsService(
        backend: backend,
        environment: AppEnvironment.staging,
        isWeb: false,
        isWebConsentGranted: () => true,
        preferencesLoader: SharedPreferences.getInstance,
      );

      await service.track(
          event: 'search_performed', parameters: {'surface': 'search_results'});
      expect(backend.events, isEmpty);
    });

    test('cola offline persiste solo eventos críticos', () async {
      final backend = _FakeBackend()..throwOnLog = true;
      final service = AnalyticsService(
        backend: backend,
        environment: AppEnvironment.prod,
        isWeb: false,
        isWebConsentGranted: () => true,
        preferencesLoader: SharedPreferences.getInstance,
      );

      await service.track(
          event: 'operator_call_click',
          parameters: {'surface': 'pharmacy_duty'});
      await service.track(
          event: 'search_performed', parameters: {'surface': 'search_results'});

      backend.throwOnLog = false;
      await service
          .track(event: 'map_viewed', parameters: {'surface': 'search_map'});

      final eventNames = backend.events.map((event) => event.name).toList();
      expect(eventNames.contains('operator_call_click'), isTrue);
      expect(eventNames.contains('search_performed'), isFalse);
    });

    test('web requiere consentimiento', () async {
      final backend = _FakeBackend();
      var consent = false;
      final service = AnalyticsService(
        backend: backend,
        environment: AppEnvironment.prod,
        isWeb: true,
        isWebConsentGranted: () => consent,
        preferencesLoader: SharedPreferences.getInstance,
      );

      await service
          .track(event: 'map_viewed', parameters: {'surface': 'search_map'});
      consent = true;
      await service.track(
        event: 'map_viewed',
        parameters: {'surface': 'search_map', 'active_zone_id': 'z1'},
      );

      expect(backend.events.length, 1);
    });
  });
}
