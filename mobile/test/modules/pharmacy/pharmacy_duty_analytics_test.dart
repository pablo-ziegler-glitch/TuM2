import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tum2/core/analytics/analytics_backend.dart';
import 'package:tum2/core/analytics/analytics_service.dart';
import 'package:tum2/core/firebase/app_environment.dart';
import 'package:tum2/modules/pharmacy/analytics/pharmacy_duty_analytics.dart';

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
  group('AnalyticsServicePharmacyDutyAnalytics', () {
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

    test('useful_action emite evento específico + evento general', () async {
      final backend = _RecordingBackend();
      final service = buildService(backend);
      final analytics = AnalyticsServicePharmacyDutyAnalytics(service);

      await analytics.logPharmacyDutyUsefulActionClicked(
        zoneId: 'z1',
        merchantId: 'm1',
        actionType: 'directions',
        distanceBucket: '1_3km',
        source: 'pharmacy_duty_list',
      );

      expect(backend.events.length, 2);
      expect(backend.events[0].name, 'pharmacy_duty_useful_action_clicked');
      expect(backend.events[1].name, 'useful_action_clicked');
      expect(
        backend.events[0].parameters,
        containsPair('action_type', 'directions'),
      );
      expect(
        backend.events[0].parameters,
        containsPair('distance_bucket', '1_3km'),
      );
    });

    test('outdated_info_confirmed/submitted incluyen reason_code', () async {
      final backend = _RecordingBackend();
      final service = buildService(backend);
      final analytics = AnalyticsServicePharmacyDutyAnalytics(service);

      await analytics.logOutdatedInfoConfirmed(
        zoneId: 'z1',
        merchantId: 'm1',
        source: 'pharmacy_duty_list',
        reasonCode: 'wrong_schedule',
      );
      await analytics.logOutdatedInfoReportSubmitted(
        zoneId: 'z1',
        merchantId: 'm1',
        source: 'pharmacy_duty_list',
        reasonCode: 'wrong_schedule',
      );

      expect(backend.events.length, 2);
      expect(backend.events[0].name, 'outdated_info_confirmed');
      expect(backend.events[1].name, 'outdated_info_report_submitted');
      expect(
        backend.events[0].parameters,
        containsPair('reason_code', 'wrong_schedule'),
      );
      expect(
        backend.events[1].parameters,
        containsPair('reason_code', 'wrong_schedule'),
      );
    });
  });
}
