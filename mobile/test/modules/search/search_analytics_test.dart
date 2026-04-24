import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tum2/core/analytics/analytics_backend.dart';
import 'package:tum2/core/analytics/analytics_service.dart';
import 'package:tum2/core/firebase/app_environment.dart';
import 'package:tum2/modules/search/analytics/search_analytics.dart';

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
  group('AnalyticsServiceSearchAnalytics', () {
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

    test('mapea search_executed con buckets de cardinalidad baja', () async {
      final backend = _RecordingBackend();
      final service = buildService(backend);
      final analytics = AnalyticsServiceSearchAnalytics(service);

      await analytics.logSearchExecuted(
        surface: 'search_results',
        zoneId: 'z1',
        queryLength: 5,
        resultsCount: 12,
      );

      expect(backend.events.length, 1);
      expect(backend.events.single.name, 'search_executed');
      expect(
        backend.events.single.parameters,
        containsPair('query_length_bucket', '4_8'),
      );
      expect(
        backend.events.single.parameters,
        containsPair('results_count_bucket', '11_plus'),
      );
      expect(
        backend.events.single.parameters,
        containsPair('zoneId', 'z1'),
      );
    });

    test('map_recenter/search_this_area no emiten evento en 0083', () async {
      final backend = _RecordingBackend();
      final service = buildService(backend);
      final analytics = AnalyticsServiceSearchAnalytics(service);

      await analytics.logMapRecenterTapped(surface: 'search_map', zoneId: 'z1');
      await analytics.logMapSearchThisAreaTapped(
        surface: 'search_map',
        zoneId: 'z1',
      );

      expect(backend.events, isEmpty);
    });
  });
}
