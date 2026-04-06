import 'package:firebase_analytics/firebase_analytics.dart';

/// Eventos de busqueda para TuM2-0056 / 0082-0083.
/// Evita PII: no envia texto de query ni datos personales.
abstract interface class SearchAnalyticsSink {
  Future<void> logQuerySubmitted({
    required int queryLength,
    required String zoneId,
    required bool hasFilters,
    required int resultsCount,
  });

  Future<void> logFilterApplied({
    required bool isOpenNow,
    required bool hasCategory,
    required bool hasMinVerification,
    required String sortBy,
  });

  Future<void> logMapToggled({
    required bool mapEnabled,
    required int resultsCount,
  });

  Future<void> logResultOpened({
    required String merchantId,
    required bool fromMap,
    required int rank,
  });

  Future<void> logZoneChanged({
    required String fromZoneId,
    required String toZoneId,
  });

  Future<void> logEmptyStateSeen({
    required String reason,
    required String zoneId,
    required bool hasQuery,
  });
}

class FirebaseSearchAnalytics implements SearchAnalyticsSink {
  FirebaseSearchAnalytics({FirebaseAnalytics? analytics})
      : _analytics = analytics ?? FirebaseAnalytics.instance;

  final FirebaseAnalytics _analytics;

  @override
  Future<void> logQuerySubmitted({
    required int queryLength,
    required String zoneId,
    required bool hasFilters,
    required int resultsCount,
  }) =>
      _analytics.logEvent(
        name: 'search_query_submitted',
        parameters: {
          'query_length': queryLength,
          'zone_id': zoneId,
          'has_filters': hasFilters,
          'results_count': resultsCount,
        },
      );

  @override
  Future<void> logFilterApplied({
    required bool isOpenNow,
    required bool hasCategory,
    required bool hasMinVerification,
    required String sortBy,
  }) =>
      _analytics.logEvent(
        name: 'search_filter_applied',
        parameters: {
          'open_now': isOpenNow,
          'has_category': hasCategory,
          'has_min_verification': hasMinVerification,
          'sort_by': sortBy,
        },
      );

  @override
  Future<void> logMapToggled({
    required bool mapEnabled,
    required int resultsCount,
  }) =>
      _analytics.logEvent(
        name: 'search_map_toggled',
        parameters: {
          'map_enabled': mapEnabled,
          'results_count': resultsCount,
        },
      );

  @override
  Future<void> logResultOpened({
    required String merchantId,
    required bool fromMap,
    required int rank,
  }) =>
      _analytics.logEvent(
        name: 'search_result_opened',
        parameters: {
          'merchant_id': merchantId,
          'from_map': fromMap,
          'rank': rank,
        },
      );

  @override
  Future<void> logZoneChanged({
    required String fromZoneId,
    required String toZoneId,
  }) =>
      _analytics.logEvent(
        name: 'search_zone_changed',
        parameters: {
          'from_zone_id': fromZoneId,
          'to_zone_id': toZoneId,
        },
      );

  @override
  Future<void> logEmptyStateSeen({
    required String reason,
    required String zoneId,
    required bool hasQuery,
  }) =>
      _analytics.logEvent(
        name: 'search_empty_state_seen',
        parameters: {
          'reason': reason,
          'zone_id': zoneId,
          'has_query': hasQuery,
        },
      );
}
