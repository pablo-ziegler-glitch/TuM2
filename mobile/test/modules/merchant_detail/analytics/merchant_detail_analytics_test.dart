import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tum2/core/analytics/analytics_backend.dart';
import 'package:tum2/core/analytics/analytics_service.dart';
import 'package:tum2/core/firebase/app_environment.dart';
import 'package:tum2/modules/merchant_detail/analytics/merchant_detail_analytics.dart';

class _RecordingBackend implements AnalyticsBackend {
  final events = <({String name, Map<String, Object> parameters})>[];

  @override
  Future<void> logEvent({
    required String name,
    required Map<String, Object> parameters,
  }) async {
    events.add((name: name, parameters: parameters));
  }

  @override
  Future<void> setUserProperty({
    required String name,
    required String? value,
  }) async {}
}

void main() {
  group('AnalyticsServiceMerchantDetailAnalytics', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    AnalyticsService buildService(_RecordingBackend backend) {
      return AnalyticsService(
        backend: backend,
        environment: AppEnvironment.prod,
        isWeb: false,
        isWebConsentGranted: () => true,
        preferencesLoader: SharedPreferences.getInstance,
      );
    }

    test('call desde open_now emite evento general + específico', () async {
      final backend = _RecordingBackend();
      final service = buildService(backend);
      final analytics = AnalyticsServiceMerchantDetailAnalytics(service);

      await analytics.logCallClick(
        merchantId: 'm1',
        zoneId: 'z1',
        categoryId: 'pharmacy',
        source: 'open_now',
        launchSucceeded: true,
      );

      expect(backend.events.length, 2);
      expect(backend.events[0].name, 'useful_action_clicked');
      expect(backend.events[1].name, 'open_now_useful_action_clicked');
      expect(
        backend.events[0].parameters,
        containsPair('action_type', 'call'),
      );
      expect(
        backend.events[1].parameters,
        containsPair('source', 'open_now'),
      );
    });

    test('call fuera de open_now emite solo evento general', () async {
      final backend = _RecordingBackend();
      final service = buildService(backend);
      final analytics = AnalyticsServiceMerchantDetailAnalytics(service);

      await analytics.logCallClick(
        merchantId: 'm1',
        zoneId: 'z1',
        categoryId: 'pharmacy',
        source: 'search_results',
        launchSucceeded: true,
      );

      expect(backend.events.length, 1);
      expect(backend.events.single.name, 'useful_action_clicked');
      expect(
        backend.events.single.parameters,
        containsPair('action_type', 'call'),
      );
    });
  });
}
