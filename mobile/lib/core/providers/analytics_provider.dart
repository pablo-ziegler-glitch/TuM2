import 'package:flutter/foundation.dart' show debugPrint, kDebugMode, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../analytics/analytics_service.dart';
import '../analytics/analytics_runtime.dart';
import 'auth_providers.dart';

const _webAnalyticsConsentPrefsKey = 'tum2.web.analytics_consent.v1';

final webAnalyticsConsentProvider = StateProvider<bool>(
  (ref) => AnalyticsRuntime.webConsentGranted,
);

final webAnalyticsConsentBootstrapProvider = FutureProvider<void>((ref) async {
  if (!kIsWeb) return;
  final prefs = await SharedPreferences.getInstance();
  final persisted = prefs.getBool(_webAnalyticsConsentPrefsKey);
  if (persisted == null) return;
  AnalyticsRuntime.webConsentGranted = persisted;
  ref.read(webAnalyticsConsentProvider.notifier).state = persisted;
});

final webAnalyticsConsentControllerProvider =
    Provider<WebAnalyticsConsentController>(
  (ref) => WebAnalyticsConsentController(ref),
);

class WebAnalyticsConsentController {
  WebAnalyticsConsentController(this._ref);

  final Ref _ref;

  Future<void> setConsent(bool granted) async {
    AnalyticsRuntime.webConsentGranted = granted;
    _ref.read(webAnalyticsConsentProvider.notifier).state = granted;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_webAnalyticsConsentPrefsKey, granted);
  }
}

final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  if (kDebugMode) {
    debugPrint('analytics runtime env active');
  }
  return AnalyticsRuntime.service;
});

final syncAnalyticsUserPropertiesProvider = FutureProvider<void>((ref) async {
  final claims = await ref.watch(authClaimsProvider.future);
  if (claims == null) return;

  final role = (claims.role ?? 'customer').trim().toLowerCase();
  const activeZoneId = 'unknown';
  final verifiedOwner = role == 'owner' && claims.merchantId != null;

  await ref.read(analyticsServiceProvider).setUserContext(
        role: role,
        activeZoneId: activeZoneId,
        isVerifiedOwner: verifiedOwner,
      );
});
