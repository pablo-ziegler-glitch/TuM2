import '../../../core/analytics/analytics_service.dart';

abstract interface class PharmacyDutyAnalyticsSink {
  Future<void> logNearbyBootstrapStarted({
    required String source,
    required String permissionState,
    required String networkState,
    required String activeZoneId,
  });

  Future<void> logNearbyBootstrapCompleted({
    required String source,
    required String activeZoneId,
    required String resultCountBucket,
  });

  Future<void> logNearbyBootstrapFailed({
    required String source,
    required String activeZoneId,
    required String reasonCode,
    required String permissionState,
    required String networkState,
  });

  Future<void> logPharmacyDutyView({
    required String activeZoneId,
    required String resultCountBucket,
  });

  Future<void> logOperatorCallClick({
    required String activeZoneId,
    required String entityZoneId,
    required String distanceBucket,
  });

  Future<void> logDirectionsOpened({
    required String activeZoneId,
    required String entityZoneId,
    required String distanceBucket,
  });

  Future<void> logFeedbackPositive({
    required String activeZoneId,
    required String entityZoneId,
    required String copyVariant,
  });

  Future<void> logFeedbackNegativeStarted({
    required String activeZoneId,
    required String entityZoneId,
  });

  Future<void> logFeedbackNegativeReasonSelected({
    required String activeZoneId,
    required String entityZoneId,
    required String reasonCode,
    required bool hasFreeText,
    required bool hasAttachment,
  });

  Future<void> logReportStarted({
    required String activeZoneId,
    required String entityZoneId,
    required String reasonCode,
  });

  Future<void> logReportSubmitted({
    required String activeZoneId,
    required String entityZoneId,
    required String reasonCode,
    required bool hasFreeText,
    required bool hasAttachment,
  });
}

class AnalyticsServicePharmacyDutyAnalytics
    implements PharmacyDutyAnalyticsSink {
  AnalyticsServicePharmacyDutyAnalytics(this._analyticsService);

  final AnalyticsService _analyticsService;

  @override
  Future<void> logNearbyBootstrapStarted({
    required String source,
    required String permissionState,
    required String networkState,
    required String activeZoneId,
  }) {
    return _analyticsService.track(
      event: 'nearby_bootstrap_started',
      parameters: {
        'surface': 'pharmacy_duty',
        'source': source,
        'permission_state': permissionState,
        'network_state': networkState,
        'active_zone_id': activeZoneId,
      },
    );
  }

  @override
  Future<void> logNearbyBootstrapCompleted({
    required String source,
    required String activeZoneId,
    required String resultCountBucket,
  }) {
    return _analyticsService.track(
      event: 'nearby_bootstrap_completed',
      parameters: {
        'surface': 'pharmacy_duty',
        'source': source,
        'active_zone_id': activeZoneId,
        'result_count_bucket': resultCountBucket,
      },
    );
  }

  @override
  Future<void> logNearbyBootstrapFailed({
    required String source,
    required String activeZoneId,
    required String reasonCode,
    required String permissionState,
    required String networkState,
  }) {
    return _analyticsService.track(
      event: 'nearby_bootstrap_failed',
      parameters: {
        'surface': 'pharmacy_duty',
        'source': source,
        'active_zone_id': activeZoneId,
        'reason_code': reasonCode,
        'permission_state': permissionState,
        'network_state': networkState,
      },
    );
  }

  @override
  Future<void> logPharmacyDutyView({
    required String activeZoneId,
    required String resultCountBucket,
  }) {
    return _analyticsService.track(
      event: 'pharmacy_duty_view',
      parameters: {
        'surface': 'pharmacy_duty',
        'entry_point': 'home',
        'active_zone_id': activeZoneId,
        'result_count_bucket': resultCountBucket,
      },
    );
  }

  @override
  Future<void> logOperatorCallClick({
    required String activeZoneId,
    required String entityZoneId,
    required String distanceBucket,
  }) {
    return _analyticsService.track(
      event: 'operator_call_click',
      parameters: {
        'surface': 'pharmacy_duty',
        'entity_type': 'pharmacy',
        'active_zone_id': activeZoneId,
        'entity_zone_id': entityZoneId,
        'distance_bucket': distanceBucket,
      },
    );
  }

  @override
  Future<void> logDirectionsOpened({
    required String activeZoneId,
    required String entityZoneId,
    required String distanceBucket,
  }) {
    return _analyticsService.track(
      event: 'directions_opened',
      parameters: {
        'surface': 'pharmacy_duty',
        'entity_type': 'pharmacy',
        'active_zone_id': activeZoneId,
        'entity_zone_id': entityZoneId,
        'distance_bucket': distanceBucket,
      },
    );
  }

  @override
  Future<void> logFeedbackPositive({
    required String activeZoneId,
    required String entityZoneId,
    required String copyVariant,
  }) {
    return _analyticsService.track(
      event: 'pharmacy_duty_feedback_positive',
      parameters: {
        'surface': 'pharmacy_duty',
        'active_zone_id': activeZoneId,
        'entity_zone_id': entityZoneId,
        'copy_variant': copyVariant,
      },
    );
  }

  @override
  Future<void> logFeedbackNegativeStarted({
    required String activeZoneId,
    required String entityZoneId,
  }) {
    return _analyticsService.track(
      event: 'pharmacy_duty_feedback_negative_started',
      parameters: {
        'surface': 'pharmacy_duty',
        'active_zone_id': activeZoneId,
        'entity_zone_id': entityZoneId,
      },
    );
  }

  @override
  Future<void> logFeedbackNegativeReasonSelected({
    required String activeZoneId,
    required String entityZoneId,
    required String reasonCode,
    required bool hasFreeText,
    required bool hasAttachment,
  }) {
    return _analyticsService.track(
      event: 'pharmacy_duty_feedback_negative_reason_selected',
      parameters: {
        'surface': 'pharmacy_duty',
        'active_zone_id': activeZoneId,
        'entity_zone_id': entityZoneId,
        'reason_code': reasonCode,
        'has_free_text': hasFreeText,
        'has_attachment': hasAttachment,
      },
    );
  }

  @override
  Future<void> logReportStarted({
    required String activeZoneId,
    required String entityZoneId,
    required String reasonCode,
  }) {
    return _analyticsService.track(
      event: 'report_started',
      parameters: {
        'surface': 'pharmacy_duty',
        'active_zone_id': activeZoneId,
        'entity_zone_id': entityZoneId,
        'reason_code': reasonCode,
      },
    );
  }

  @override
  Future<void> logReportSubmitted({
    required String activeZoneId,
    required String entityZoneId,
    required String reasonCode,
    required bool hasFreeText,
    required bool hasAttachment,
  }) {
    return _analyticsService.track(
      event: 'report_submitted',
      parameters: {
        'surface': 'pharmacy_duty',
        'active_zone_id': activeZoneId,
        'entity_zone_id': entityZoneId,
        'reason_code': reasonCode,
        'has_free_text': hasFreeText,
        'has_attachment': hasAttachment,
      },
    );
  }
}

class NoopPharmacyDutyAnalytics implements PharmacyDutyAnalyticsSink {
  @override
  Future<void> logDirectionsOpened({
    required String activeZoneId,
    required String entityZoneId,
    required String distanceBucket,
  }) async {}

  @override
  Future<void> logFeedbackNegativeReasonSelected({
    required String activeZoneId,
    required String entityZoneId,
    required String reasonCode,
    required bool hasFreeText,
    required bool hasAttachment,
  }) async {}

  @override
  Future<void> logFeedbackNegativeStarted({
    required String activeZoneId,
    required String entityZoneId,
  }) async {}

  @override
  Future<void> logFeedbackPositive({
    required String activeZoneId,
    required String entityZoneId,
    required String copyVariant,
  }) async {}

  @override
  Future<void> logNearbyBootstrapCompleted({
    required String source,
    required String activeZoneId,
    required String resultCountBucket,
  }) async {}

  @override
  Future<void> logNearbyBootstrapFailed({
    required String source,
    required String activeZoneId,
    required String reasonCode,
    required String permissionState,
    required String networkState,
  }) async {}

  @override
  Future<void> logNearbyBootstrapStarted({
    required String source,
    required String permissionState,
    required String networkState,
    required String activeZoneId,
  }) async {}

  @override
  Future<void> logOperatorCallClick({
    required String activeZoneId,
    required String entityZoneId,
    required String distanceBucket,
  }) async {}

  @override
  Future<void> logPharmacyDutyView({
    required String activeZoneId,
    required String resultCountBucket,
  }) async {}

  @override
  Future<void> logReportStarted({
    required String activeZoneId,
    required String entityZoneId,
    required String reasonCode,
  }) async {}

  @override
  Future<void> logReportSubmitted({
    required String activeZoneId,
    required String entityZoneId,
    required String reasonCode,
    required bool hasFreeText,
    required bool hasAttachment,
  }) async {}
}
