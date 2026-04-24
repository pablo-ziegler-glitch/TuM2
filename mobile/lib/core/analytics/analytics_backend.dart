import 'package:firebase_analytics/firebase_analytics.dart';

abstract interface class AnalyticsBackend {
  Future<void> logEvent({
    required String name,
    required Map<String, Object> parameters,
  });

  Future<void> setUserProperty({
    required String name,
    required String? value,
  });
}

class FirebaseAnalyticsBackend implements AnalyticsBackend {
  FirebaseAnalyticsBackend({FirebaseAnalytics? analytics})
      : _analytics = analytics ?? FirebaseAnalytics.instance;

  final FirebaseAnalytics _analytics;

  @override
  Future<void> logEvent({
    required String name,
    required Map<String, Object> parameters,
  }) {
    return _analytics.logEvent(name: name, parameters: parameters);
  }

  @override
  Future<void> setUserProperty({
    required String name,
    required String? value,
  }) {
    return _analytics.setUserProperty(name: name, value: value);
  }
}
