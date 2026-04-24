import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase/app_environment.dart';
import 'analytics_backend.dart';
import 'analytics_service.dart';

class AnalyticsRuntime {
  AnalyticsRuntime._();

  static bool webConsentGranted = !kIsWeb;

  static final AnalyticsService service = AnalyticsService(
    backend: FirebaseAnalyticsBackend(),
    environment: AppEnvironmentConfig.current,
    isWeb: kIsWeb,
    isWebConsentGranted: () => webConsentGranted,
    preferencesLoader: SharedPreferences.getInstance,
    logger: (message) {
      if (kDebugMode) {
        // ignore: avoid_print
        print(message);
      }
    },
  );
}
