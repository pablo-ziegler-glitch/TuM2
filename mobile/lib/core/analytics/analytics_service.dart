import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase/app_environment.dart';
import 'analytics_backend.dart';

typedef AnalyticsLogger = void Function(String message);
typedef PreferencesLoader = Future<SharedPreferences> Function();

class AnalyticsService {
  AnalyticsService({
    required AnalyticsBackend backend,
    required AppEnvironment environment,
    required bool isWeb,
    required bool Function() isWebConsentGranted,
    required PreferencesLoader preferencesLoader,
    DateTime Function()? now,
    AnalyticsLogger? logger,
  })  : _backend = backend,
        _environment = environment,
        _isWeb = isWeb,
        _isWebConsentGranted = isWebConsentGranted,
        _preferencesLoader = preferencesLoader,
        _now = now ?? DateTime.now,
        _logger = logger ?? debugPrint;

  final AnalyticsBackend _backend;
  final AppEnvironment _environment;
  final bool _isWeb;
  final bool Function() _isWebConsentGranted;
  final PreferencesLoader _preferencesLoader;
  final DateTime Function() _now;
  final AnalyticsLogger _logger;

  static const _queueStorageKey = 'tum2.analytics.offline_queue.v1';
  static const _queueMaxSize = 24;
  static const _queueItemTtl = Duration(hours: 6);
  static const _dedupeWindow = Duration(seconds: 2);
  static const _maxStringLength = 72;
  static const _maxRawQueueBytes = 60000;

  static const Set<String> _offlineAllowedEvents = {
    // Canonical 0083 critical actions
    'useful_action_clicked',
    'open_now_useful_action_clicked',
    'pharmacy_duty_useful_action_clicked',
    'outdated_info_report_submitted',
    'claim_step_completed',
    'claim_abandoned',
    // Canonical 0082 compatibility
    'operator_call_click',
    'whatsapp_chat_started',
    'directions_opened',
    'pharmacy_duty_view',
    'claim_started',
    'claim_evidence_uploaded',
    'claim_submitted',
    'pharmacy_duty_feedback_positive',
    'report_submitted',
  };

  static const Set<String> _allowedEventNames = {
    // Canonical 0083
    'session_started',
    'zone_resolved',
    'surface_viewed',
    'search_executed',
    'search_results_viewed',
    'search_filter_applied',
    'merchant_card_impression',
    'merchant_detail_opened',
    'useful_action_clicked',
    'open_now_viewed',
    'open_now_merchant_opened',
    'open_now_useful_action_clicked',
    'pharmacy_duty_list_viewed',
    'pharmacy_duty_detail_opened',
    'pharmacy_duty_useful_action_clicked',
    'outdated_info_tapped',
    'outdated_info_confirmed',
    'outdated_info_report_submitted',
    'claim_step_completed',
    'claim_abandoned',
    // Canonical 0082
    'search_performed',
    'category_filtered',
    'nearby_bootstrap_started',
    'nearby_bootstrap_completed',
    'nearby_bootstrap_failed',
    'map_viewed',
    'map_pin_selected',
    'map_recenter_tapped',
    'map_search_this_area_tapped',
    'operator_call_click',
    'whatsapp_chat_started',
    'directions_opened',
    'pharmacy_duty_view',
    'pharmacy_duty_feedback_positive',
    'pharmacy_duty_feedback_negative_started',
    'pharmacy_duty_feedback_negative_reason_selected',
    'report_started',
    'report_submitted',
    'claim_started',
    'claim_evidence_uploaded',
    'claim_submitted',
    // Legacy (migrados a AnalyticsService, mantener sin renombrar).
    'merchant_detail_view',
    'merchant_detail_share_click',
    'merchant_detail_duty_banner_view',
    'merchant_detail_error',
    'auth_magic_link_sent',
    'auth_magic_link_verified',
    'auth_magic_link_error',
    'auth_google_sign_in',
    'auth_google_sign_in_error',
    'auth_sign_out',
    'auth_display_name_set',
    'auth_display_name_skipped',
    'onboarding_owner_started',
    'onboarding_owner_step_completed',
    'onboarding_owner_step_3_skipped',
    'onboarding_owner_submitted',
    'onboarding_owner_completed',
    'onboarding_owner_exited',
    'onboarding_owner_draft_resumed',
    'onboarding_owner_draft_discarded',
    'onboarding_owner_error',
    'onboarding_owner_duplicate_soft',
    'onboarding_owner_duplicate_hard',
    'open_now_view_opened',
    'open_now_results_loaded',
    'open_now_empty_state_shown',
    'open_now_fallback_shown',
    'open_now_pull_to_refresh',
    'open_now_card_clicked',
    'open_now_distance_permission_denied',
    'open_now_location_unavailable',
    'merchant_claim_started',
    'merchant_claim_step_viewed',
    'merchant_claim_step_completed',
    'merchant_claim_evidence_uploaded',
    'merchant_claim_evidence_requirements_viewed',
    'merchant_claim_category_specific_help_viewed',
    'merchant_claim_evidence_upload_started',
    'merchant_claim_evidence_upload_completed',
    'merchant_claim_evidence_upload_failed',
    'merchant_claim_sent_to_manual_review',
    'merchant_claim_submitted',
    'merchant_claim_submission_failed',
    'merchant_claim_status_viewed',
    'owner_dashboard_viewed',
    'owner_dashboard_quick_action_tapped',
    'owner_dashboard_alert_tapped',
    'owner_dashboard_empty_state_viewed',
    'owner_dashboard_error_viewed',
    'owner_dashboard_restricted_viewed',
    'owner_dashboard_merchant_switched',
    'owner_schedule_viewed',
    'owner_schedule_edit_started',
    'owner_schedule_saved',
    'owner_schedule_save_failed',
    'owner_schedule_exception_created',
    'owner_schedule_exception_deleted',
    'owner_schedule_screen_view',
    'owner_schedule_mode_selected',
    'owner_schedule_apply_weekdays_template',
    'owner_schedule_add_exception',
    'owner_schedule_save_success',
    'owner_schedule_save_error',
    'owner_schedule_validation_error',
    'product_created',
    'product_edited',
    'product_deactivated',
    'product_hidden',
    'product_made_visible',
    'product_image_uploaded',
    'product_image_upload_failed',
    'owner_catalog_limit_warning_seen',
    'owner_catalog_limit_block_seen',
    'owner_contact_admin_from_catalog_limit',
    'owner_product_create_blocked_by_limit',
    'owner_signal_viewed',
    'owner_signal_create_started',
    'owner_signal_activated',
    'owner_signal_deactivated',
    'owner_signal_save_failed',
    'owner_operational_preview_viewed',
    'owner_operational_signal_opened',
    'owner_operational_signal_saved',
    'senal_creada',
    'owner_operational_signal_disabled',
    'senal_desactivada',
    'owner_operational_signal_save_failed',
    'token_force_refresh_started',
    'token_force_refresh_succeeded',
    'token_force_refresh_failed',
    'role_transition_detected',
    'owner_access_unlocked',
    'pharmacy_duty_confirmation_prompt_seen',
    'pharmacy_duty_confirmed',
    'pharmacy_duty_incident_reported',
    'pharmacy_reassignment_candidates_loaded',
    'pharmacy_reassignment_round_created',
    'pharmacy_reassignment_request_accepted',
    'pharmacy_reassignment_request_rejected',
    'pharmacy_reassignment_round_expired',
    'pharmacy_duty_reassigned_successfully',
  };

  static const Set<String> _allowedParameterKeys = {
    // Canonical 0083
    'zoneId',
    'categoryId',
    'action_type',
    'role',
    'platform',
    'is_open_now_shown',
    'is_on_duty_shown',
    'has_message',
    'has_end_date',
    'results_count_bucket',
    'elapsed_time_bucket',
    // Canonical 0082
    'surface',
    'entry_point',
    'source',
    'entity_type',
    'active_zone_id',
    'entity_zone_id',
    'distance_bucket',
    'resolved_locally',
    'result_count_bucket',
    'permission_state',
    'network_state',
    'reason_code',
    'has_free_text',
    'has_attachment',
    'copy_variant',
    'search_mode',
    'query_length_bucket',
    'used_category_filter',
    'used_open_now_filter',
    'used_distance_sort',
    'category_id',
    'evidence_count_bucket',
    // Legacy transitorio (sin IDs de entidad para reducir exposición).
    'has_pharmacy_duty_today',
    'has_ends_at',
    'stage',
    'error_type',
    'launch_succeeded',
    'is_new_user',
    'is_cross_device',
    'error_code',
    'step',
    'zone_id',
    'results_count',
    'fallback_count',
    'has_location',
    'data_freshness_bucket',
    'top_result_verification_status',
    'status',
    'reason',
    'step_id',
    'evidence_kind',
    'policy_version',
    'claim_status',
    'action_id',
    'alert_id',
    'restriction_state',
    'day_key',
    'mode',
    'exception_kind',
    'weekly_errors',
    'exception_errors',
    'closure_errors',
    'signal_type',
    'is_active',
    'force_closed',
    'save_result',
    'source_screen',
    'refresh_reason',
    'previous_role',
    'new_role',
    'owner_pending_before',
    'owner_pending_after',
    'result',
    'has_image',
    'stock_status',
    'visibility_status',
    'latency_ms',
    'image_size_bytes',
    'used',
    'limit',
    'candidate_count',
    'time_to_recover_seconds',
    'rank',
    'is_fallback',
  };

  static const Set<String> _blockedParameterKeys = {
    'merchantId',
    'productId',
    'merchantRef',
    'userId',
    'deviceId',
    'sessionId',
    'searchQuery',
    'queryText',
    'freeText',
    'attachmentUrl',
    'fileName',
    'rawCoordinates',
    'merchant_id',
    'product_id',
    'merchant_ref',
    'user_id',
    'uid',
    'device_id',
    'session_id',
    'query',
    'search_query',
    'query_text',
    'text',
    'free_text',
    'note',
    'message',
    'phone',
    'email',
    'attachment',
    'attachment_url',
    'file',
    'file_name',
    'lat',
    'lng',
    'latitude',
    'longitude',
    'raw_coordinates',
  };

  static const Map<String, Set<String>> _enumAllowList = {
    'distance_bucket': {
      '0_500m',
      '500m_1km',
      '1_3km',
      '3_10km',
      '10km_plus',
      'unknown',
    },
    'result_count_bucket': {'0', '1_3', '4_10', '11_plus'},
    'query_length_bucket': {'0', '1_3', '4_8', '9_plus'},
    'evidence_count_bucket': {'1', '2', '3_plus'},
    'copy_variant': {'default_me_sirvio', 'seasonal_messirve'},
    'action_type': {'whatsapp', 'call', 'directions'},
    'results_count_bucket': {'0', '1_3', '4_10', '11_plus'},
    'elapsed_time_bucket': {'lt_1m', '1_3m', '3_10m', '10m_plus'},
    'platform': {'mobile', 'web'},
    'role': {'customer', 'owner', 'admin', 'super_admin', 'guest', 'unknown'},
  };

  final Map<String, DateTime> _recentDedupes = <String, DateTime>{};
  Future<void>? _flushInFlight;
  String? _lastRole;
  String? _lastActiveZoneId;
  String? _lastVerifiedOwner;
  late final DateTime _sessionStartedAt = _now();

  Future<void> setUserContext({
    required String role,
    required String activeZoneId,
    required bool isVerifiedOwner,
  }) async {
    final normalizedRole = _normalizeSmallString(role) ?? 'customer';
    final normalizedZone = _normalizeSmallString(activeZoneId) ?? 'unknown';
    final ownerValue = isVerifiedOwner ? 'true' : 'false';

    if (_isTrackingEnabled) {
      if (_lastRole != normalizedRole) {
        await _safeSetUserProperty(name: 'role', value: normalizedRole);
        _lastRole = normalizedRole;
      }
      if (_lastActiveZoneId != normalizedZone) {
        await _safeSetUserProperty(
            name: 'active_zone_id', value: normalizedZone);
        _lastActiveZoneId = normalizedZone;
      }
      if (_lastVerifiedOwner != ownerValue) {
        await _safeSetUserProperty(
            name: 'is_verified_owner', value: ownerValue);
        _lastVerifiedOwner = ownerValue;
      }
      return;
    }

    _lastRole = normalizedRole;
    _lastActiveZoneId = normalizedZone;
    _lastVerifiedOwner = ownerValue;
  }

  Future<void> setActiveZoneId(String activeZoneId) async {
    final normalizedZone = _normalizeSmallString(activeZoneId) ?? 'unknown';
    if (_lastActiveZoneId == normalizedZone) return;
    _lastActiveZoneId = normalizedZone;
    if (!_isTrackingEnabled) return;
    await _safeSetUserProperty(name: 'active_zone_id', value: normalizedZone);
  }

  Future<void> track({
    required String event,
    Map<String, Object?> parameters = const {},
    bool dedupe = true,
    Duration dedupeWindow = _dedupeWindow,
  }) async {
    if (!_allowedEventNames.contains(event)) {
      if (_environment != AppEnvironment.prod) {
        _logger('analytics[blocked_event] $event');
      }
      return;
    }

    final sanitized = _sanitizeParameters(parameters);
    final signature = _signatureFor(event: event, parameters: sanitized);
    final now = _now();
    if (dedupe &&
        _isDuplicated(signature: signature, now: now, window: dedupeWindow)) {
      return;
    }

    if (_isTrackingEnabled) {
      await _flushOfflineQueue();
      try {
        await _backend.logEvent(name: event, parameters: sanitized);
        return;
      } catch (_) {
        if (_offlineAllowedEvents.contains(event)) {
          await _enqueueOffline(
            _QueuedAnalyticsEvent(
              name: event,
              parameters: sanitized,
              queuedAtMillis: now.millisecondsSinceEpoch,
            ),
          );
        }
        return;
      }
    }

    if (_environment != AppEnvironment.prod) {
      _logger('analytics[debug] $event $sanitized');
    }
  }

  String distanceBucket(double? meters) {
    if (meters == null || meters.isNaN || meters.isInfinite || meters < 0) {
      return 'unknown';
    }
    if (meters <= 500) return '0_500m';
    if (meters <= 1000) return '500m_1km';
    if (meters <= 3000) return '1_3km';
    if (meters <= 10000) return '3_10km';
    return '10km_plus';
  }

  String resultCountBucket(int count) {
    if (count <= 0) return '0';
    if (count <= 3) return '1_3';
    if (count <= 10) return '4_10';
    return '11_plus';
  }

  String queryLengthBucket(int length) {
    if (length <= 0) return '0';
    if (length <= 3) return '1_3';
    if (length <= 8) return '4_8';
    return '9_plus';
  }

  String evidenceCountBucket(int count) {
    if (count <= 1) return '1';
    if (count == 2) return '2';
    return '3_plus';
  }

  String elapsedTimeBucketNow() {
    final elapsed = _now().difference(_sessionStartedAt);
    if (elapsed.inSeconds < 60) return 'lt_1m';
    if (elapsed.inMinutes < 3) return '1_3m';
    if (elapsed.inMinutes < 10) return '3_10m';
    return '10m_plus';
  }

  String get platform => _isWeb ? 'web' : 'mobile';

  bool get _isTrackingEnabled {
    if (_environment != AppEnvironment.prod) return false;
    if (_isWeb && !_isWebConsentGranted()) return false;
    return true;
  }

  bool _isDuplicated({
    required String signature,
    required DateTime now,
    required Duration window,
  }) {
    _recentDedupes
        .removeWhere((_, timestamp) => now.difference(timestamp) > window);
    final previous = _recentDedupes[signature];
    if (previous != null && now.difference(previous) <= window) {
      return true;
    }
    _recentDedupes[signature] = now;
    return false;
  }

  Future<void> _safeSetUserProperty({
    required String name,
    required String value,
  }) async {
    try {
      await _backend.setUserProperty(name: name, value: value);
    } catch (_) {
      // Analytics nunca debe romper el flujo.
    }
  }

  Map<String, Object> _sanitizeParameters(Map<String, Object?> input) {
    final output = <String, Object>{};
    for (final entry in input.entries) {
      final key = entry.key.trim();
      if (key.isEmpty) continue;
      if (!_allowedParameterKeys.contains(key)) continue;
      if (_blockedParameterKeys.contains(key)) continue;
      final value = entry.value;
      if (value == null) continue;

      if (value is bool || value is int || value is double) {
        if (value is num && _looksSensitiveNumber(key, value)) continue;
        output[key] = value;
        continue;
      }
      if (value is String) {
        final normalized = _normalizeParameterString(key, value);
        if (normalized == null) continue;
        output[key] = normalized;
      }
    }
    return output;
  }

  String? _normalizeParameterString(String key, String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;
    if (_looksSensitive(value)) return null;

    final enumValues = _enumAllowList[key];
    if (enumValues != null && !enumValues.contains(value)) {
      return null;
    }

    if (value.length > _maxStringLength) return null;
    return value;
  }

  bool _looksSensitive(String input) {
    final emailLike = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(input);
    if (emailLike) return true;
    final hasUrl =
        RegExp(r'^(https?:\/\/|www\.)', caseSensitive: false).hasMatch(input);
    if (hasUrl) return true;
    final digits = input.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length >= 8) return true;
    final hasCoordinates =
        RegExp(r'^-?\d{1,2}\.\d+,\s*-?\d{1,3}\.\d+$').hasMatch(input);
    return hasCoordinates;
  }

  bool _looksSensitiveNumber(String key, num value) {
    final normalized = key.toLowerCase();
    if (normalized.contains('lat') || normalized.contains('lng')) return true;
    if (normalized.contains('coord')) return true;
    if ((normalized.contains('phone') || normalized.contains('dni')) &&
        value.abs() >= 1000000) {
      return true;
    }
    return false;
  }

  String? _normalizeSmallString(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) return null;
    if (normalized.length > _maxStringLength) {
      return normalized.substring(0, _maxStringLength);
    }
    return normalized;
  }

  String _signatureFor({
    required String event,
    required Map<String, Object> parameters,
  }) {
    final sorted = parameters.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return '$event|${sorted.map((e) => '${e.key}:${e.value}').join('|')}';
  }

  Future<void> _flushOfflineQueue() async {
    if (_flushInFlight != null) return _flushInFlight!;
    final task = _flushOfflineQueueInternal();
    _flushInFlight = task;
    try {
      await task;
    } finally {
      _flushInFlight = null;
    }
  }

  Future<void> _flushOfflineQueueInternal() async {
    final prefs = await _preferencesLoader();
    final queued = _readQueue(prefs);
    if (queued.isEmpty) return;

    final nowMillis = _now().millisecondsSinceEpoch;
    final valid = queued.where((event) {
      return nowMillis - event.queuedAtMillis <= _queueItemTtl.inMilliseconds;
    }).toList(growable: true);
    if (valid.isEmpty) {
      await prefs.remove(_queueStorageKey);
      return;
    }

    final remaining = <_QueuedAnalyticsEvent>[];
    for (final event in valid) {
      try {
        await _backend.logEvent(name: event.name, parameters: event.parameters);
      } catch (_) {
        remaining.add(event);
      }
    }
    await _persistQueue(prefs, remaining);
  }

  Future<void> _enqueueOffline(_QueuedAnalyticsEvent event) async {
    final prefs = await _preferencesLoader();
    final nowMillis = _now().millisecondsSinceEpoch;
    final existing = _readQueue(prefs).where((item) {
      return nowMillis - item.queuedAtMillis <= _queueItemTtl.inMilliseconds;
    }).toList(growable: true);

    final alreadyInQueue = existing.any((queued) {
      return queued.name == event.name &&
          _sameParameters(queued.parameters, event.parameters);
    });
    if (alreadyInQueue) return;

    existing.add(event);
    if (existing.length > _queueMaxSize) {
      existing.removeRange(0, existing.length - _queueMaxSize);
    }
    await _persistQueue(prefs, existing);
  }

  List<_QueuedAnalyticsEvent> _readQueue(SharedPreferences prefs) {
    final raw = prefs.getString(_queueStorageKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final parsed = <_QueuedAnalyticsEvent>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        final casted = <String, dynamic>{};
        for (final entry in item.entries) {
          casted['${entry.key}'] = entry.value;
        }
        parsed.add(_QueuedAnalyticsEvent.fromJson(casted));
      }
      return parsed;
    } catch (_) {
      return const [];
    }
  }

  Future<void> _persistQueue(
    SharedPreferences prefs,
    List<_QueuedAnalyticsEvent> queue,
  ) async {
    if (queue.isEmpty) {
      await prefs.remove(_queueStorageKey);
      return;
    }
    final payload = jsonEncode(queue.map((event) => event.toJson()).toList());
    if (payload.length > _maxRawQueueBytes) {
      final trimmed = queue.skip(queue.length ~/ 2).toList(growable: false);
      final trimmedPayload = jsonEncode(
        trimmed.map((event) => event.toJson()).toList(),
      );
      await prefs.setString(_queueStorageKey, trimmedPayload);
      return;
    }
    await prefs.setString(_queueStorageKey, payload);
  }

  bool _sameParameters(
    Map<String, Object> a,
    Map<String, Object> b,
  ) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (!b.containsKey(entry.key)) return false;
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }
}

class _QueuedAnalyticsEvent {
  const _QueuedAnalyticsEvent({
    required this.name,
    required this.parameters,
    required this.queuedAtMillis,
  });

  final String name;
  final Map<String, Object> parameters;
  final int queuedAtMillis;

  Map<String, Object> toJson() {
    return {
      'name': name,
      'queuedAtMillis': queuedAtMillis,
      'parameters': parameters,
    };
  }

  static _QueuedAnalyticsEvent fromJson(Map<String, dynamic> json) {
    final rawParams = json['parameters'];
    final params = <String, Object>{};
    if (rawParams is Map) {
      for (final entry in rawParams.entries) {
        final key = '${entry.key}'.trim();
        if (key.isEmpty) continue;
        final value = entry.value;
        if (value is String ||
            value is int ||
            value is double ||
            value is bool) {
          params[key] = value;
        }
      }
    }
    return _QueuedAnalyticsEvent(
      name: (json['name'] as String? ?? '').trim(),
      parameters: params,
      queuedAtMillis: (json['queuedAtMillis'] as num?)?.toInt() ?? 0,
    );
  }
}
