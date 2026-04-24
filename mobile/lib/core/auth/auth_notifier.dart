import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../analytics/analytics_runtime.dart';
import 'access_claims.dart';
import 'auth_state.dart';
import 'owner_access_summary.dart';

enum AuthSessionRefreshReason {
  splash,
  postLogin,
  claimStatus,
  ownerAccessUpdate,
  ownerPanel,
  manualRetry,
  backgroundSync,
}

extension on AuthSessionRefreshReason {
  String get analyticsValue {
    switch (this) {
      case AuthSessionRefreshReason.splash:
        return 'splash';
      case AuthSessionRefreshReason.postLogin:
        return 'post_login';
      case AuthSessionRefreshReason.claimStatus:
        return 'claim_status';
      case AuthSessionRefreshReason.ownerAccessUpdate:
        return 'owner_access_update';
      case AuthSessionRefreshReason.ownerPanel:
        return 'owner_panel';
      case AuthSessionRefreshReason.manualRetry:
        return 'manual_retry';
      case AuthSessionRefreshReason.backgroundSync:
        return 'background_sync';
    }
  }
}

class _UserAccessSnapshot {
  const _UserAccessSnapshot({
    required this.role,
    required this.ownerPending,
    required this.merchantId,
    required this.accessVersion,
    required this.ownerAccessSummary,
  });

  final String? role;
  final bool? ownerPending;
  final String? merchantId;
  final int? accessVersion;
  final OwnerAccessSummary? ownerAccessSummary;
}

class _AccessTransitionSnapshot {
  const _AccessTransitionSnapshot({
    required this.role,
    required this.ownerPending,
  });

  final String role;
  final bool ownerPending;
}

/// Notifier reactivo sobre el estado de autenticación de Firebase.
///
/// - Fuerza refresh de token en splash/post-login.
/// - Usa claims mínimas (`role`, `owner_pending`, `access_version`).
/// - Resuelve contexto OWNER desde `users/{uid}.ownerAccessSummary` con cache TTL.
class AuthNotifier extends ChangeNotifier {
  AuthState _authState = const AuthLoading();
  AuthState get authState => _authState;

  int _eventVersion = 0;
  StreamSubscription<User?>? _authSub;
  bool _initialSessionResolved = false;
  String? _lastResolvedUid;
  _AccessTransitionSnapshot? _lastTransitionSnapshot;

  static const _userDocCacheTtl = Duration(seconds: 45);
  String? _cachedUid;
  DateTime? _cachedAt;
  _UserAccessSnapshot? _cachedSnapshot;

  AuthNotifier() {
    _authSub = FirebaseAuth.instance.authStateChanges().listen(_onUserChanged);
  }

  Future<void> _onUserChanged(
    User? user, {
    bool forceUserDocRead = false,
    AuthSessionRefreshReason? forcedRefreshReason,
    bool rethrowRefreshError = false,
  }) async {
    final version = ++_eventVersion;

    if (user == null) {
      _cachedUid = null;
      _cachedAt = null;
      _cachedSnapshot = null;
      _lastResolvedUid = null;
      _lastTransitionSnapshot = null;
      _authState = const AuthUnauthenticated();
      _initialSessionResolved = true;
      notifyListeners();
      return;
    }

    final refreshReason =
        forcedRefreshReason ?? _resolveRefreshReason(user.uid);

    try {
      final tokenResult = await _refreshTokenWithTelemetry(
        user: user,
        reason: refreshReason,
      );
      final claims = AccessClaims.fromTokenClaims(tokenResult.claims);

      String role = claims.role;
      final ownerPendingFromToken = claims.ownerPending;
      final accessVersionFromToken = claims.accessVersion;

      final userSnapshot = await _resolveUserAccessSnapshot(
        uid: user.uid,
        tokenAccessVersion: accessVersionFromToken,
        roleFromToken: role,
        forceUserDocRead: forceUserDocRead,
      );

      role = userSnapshot.role?.toLowerCase() ?? role;
      final ownerAccessSummary = userSnapshot.ownerAccessSummary;
      final merchantId =
          ownerAccessSummary?.defaultMerchantId ?? userSnapshot.merchantId;
      final ownerPending = userSnapshot.ownerPending ?? ownerPendingFromToken;
      final accessVersion =
          userSnapshot.accessVersion ?? accessVersionFromToken;
      final hasApprovedMerchants =
          ownerAccessSummary?.approvedMerchantIdsCount != null &&
              ownerAccessSummary!.approvedMerchantIdsCount > 0;

      if (version != _eventVersion) return;

      _authState = AuthAuthenticated(
        user: user,
        role: role,
        accessVersion: accessVersion ?? 0,
        merchantId: merchantId,
        onboardingComplete: hasApprovedMerchants || merchantId != null,
        ownerPending: ownerPending,
        isAdmin: claims.isAdmin,
        isSuperAdmin: claims.isSuperAdmin,
        claimsUpdatedAtSeconds: claims.claimsUpdatedAtSeconds,
        ownerAccessSummary: ownerAccessSummary,
      );
      _logAccessTransitionIfNeeded(
        role: role,
        ownerPending: ownerPending,
        reason: refreshReason,
      );
      _lastResolvedUid = user.uid;
      _initialSessionResolved = true;
    } catch (error) {
      if (version != _eventVersion) return;
      if (kDebugMode) {
        debugPrint('[AuthNotifier] fallback por error de sesión: $error');
      }
      _authState = AuthAuthenticated(
        user: user,
        role: 'customer',
        accessVersion: 0,
        merchantId: null,
        onboardingComplete: false,
        ownerPending: false,
        isAdmin: false,
        isSuperAdmin: false,
        claimsUpdatedAtSeconds: null,
      );
      _logAccessTransitionIfNeeded(
        role: 'customer',
        ownerPending: false,
        reason: refreshReason,
      );
      _lastResolvedUid = user.uid;
      _initialSessionResolved = true;
      if (rethrowRefreshError) {
        rethrow;
      }
    }

    notifyListeners();
  }

  AuthSessionRefreshReason _resolveRefreshReason(String uid) {
    if (!_initialSessionResolved) return AuthSessionRefreshReason.splash;
    if (_lastResolvedUid == null || _lastResolvedUid != uid) {
      return AuthSessionRefreshReason.postLogin;
    }
    return AuthSessionRefreshReason.backgroundSync;
  }

  Future<IdTokenResult> _refreshTokenWithTelemetry({
    required User user,
    required AuthSessionRefreshReason reason,
  }) async {
    final startedAt = DateTime.now();
    unawaited(
      AnalyticsRuntime.service.track(
        event: 'token_force_refresh_started',
        parameters: {
          'source_screen': reason.analyticsValue,
          'refresh_reason': reason.analyticsValue,
          'result': 'started',
        },
      ),
    );

    try {
      final result = await user.getIdTokenResult(true);
      final latency = DateTime.now().difference(startedAt).inMilliseconds;
      unawaited(
        AnalyticsRuntime.service.track(
          event: 'token_force_refresh_succeeded',
          parameters: {
            'source_screen': reason.analyticsValue,
            'refresh_reason': reason.analyticsValue,
            'latency_ms': latency,
            'result': 'succeeded',
          },
        ),
      );
      return result;
    } on FirebaseAuthException catch (error) {
      final latency = DateTime.now().difference(startedAt).inMilliseconds;
      unawaited(
        AnalyticsRuntime.service.track(
          event: 'token_force_refresh_failed',
          parameters: {
            'source_screen': reason.analyticsValue,
            'refresh_reason': reason.analyticsValue,
            'latency_ms': latency,
            'result': 'failed',
            'error_code': error.code,
          },
        ),
      );
      rethrow;
    }
  }

  void _logAccessTransitionIfNeeded({
    required String role,
    required bool ownerPending,
    required AuthSessionRefreshReason reason,
  }) {
    final current =
        _AccessTransitionSnapshot(role: role, ownerPending: ownerPending);
    final previous = _lastTransitionSnapshot;
    _lastTransitionSnapshot = current;
    if (previous == null) return;

    if (previous.role != current.role ||
        previous.ownerPending != current.ownerPending) {
      unawaited(
        AnalyticsRuntime.service.track(
          event: 'role_transition_detected',
          parameters: {
            'source_screen': reason.analyticsValue,
            'refresh_reason': reason.analyticsValue,
            'previous_role': previous.role,
            'new_role': current.role,
            'owner_pending_before': previous.ownerPending ? 'true' : 'false',
            'owner_pending_after': current.ownerPending ? 'true' : 'false',
            'result': 'transition',
          },
        ),
      );
    }

    if (current.role == 'owner' &&
        !current.ownerPending &&
        (previous.role != 'owner' || previous.ownerPending)) {
      unawaited(
        AnalyticsRuntime.service.track(
          event: 'owner_access_unlocked',
          parameters: {
            'source_screen': reason.analyticsValue,
            'refresh_reason': reason.analyticsValue,
            'previous_role': previous.role,
            'new_role': current.role,
            'owner_pending_before': previous.ownerPending ? 'true' : 'false',
            'owner_pending_after': 'false',
            'result': 'unlocked',
          },
        ),
      );
    }
  }

  Future<_UserAccessSnapshot> _resolveUserAccessSnapshot({
    required String uid,
    required int? tokenAccessVersion,
    required String? roleFromToken,
    required bool forceUserDocRead,
  }) async {
    final cached = _cachedSnapshot;
    if (!forceUserDocRead && _cachedUid == uid && cached != null) {
      final isOwnerLike = (roleFromToken?.toLowerCase() == 'owner') ||
          ((cached.role?.toLowerCase() == 'owner'));
      final needsOwnerSummary =
          isOwnerLike && cached.ownerAccessSummary == null;
      final cachedVersion = cached.accessVersion;
      final sameVersion = tokenAccessVersion != null &&
          cachedVersion != null &&
          cachedVersion == tokenAccessVersion;
      final recentlyFetched = _cachedAt != null &&
          DateTime.now().difference(_cachedAt!) <= _userDocCacheTtl;

      if ((sameVersion || tokenAccessVersion == null || recentlyFetched) &&
          !needsOwnerSummary) {
        return cached;
      }
    }
    return _fetchUserDataFromFirestore(
      uid,
      tokenAccessVersion: tokenAccessVersion,
    );
  }

  Future<_UserAccessSnapshot> _fetchUserDataFromFirestore(
    String uid, {
    int? tokenAccessVersion,
  }) async {
    final now = DateTime.now();
    final cacheFresh = _cachedUid == uid &&
        _cachedAt != null &&
        now.difference(_cachedAt!) <= _userDocCacheTtl;
    final cachedVersion = _cachedSnapshot?.accessVersion;
    final shouldUseCache = cacheFresh &&
        _cachedSnapshot != null &&
        (tokenAccessVersion == null ||
            cachedVersion == null ||
            cachedVersion == tokenAccessVersion);
    if (shouldUseCache) return _cachedSnapshot!;

    try {
      final doc = await FirebaseFirestore.instance.doc('users/$uid').get();
      if (!doc.exists) {
        const empty = _UserAccessSnapshot(
          role: null,
          ownerPending: null,
          merchantId: null,
          accessVersion: null,
          ownerAccessSummary: null,
        );
        _cachedUid = uid;
        _cachedAt = now;
        _cachedSnapshot = empty;
        return empty;
      }

      final data = doc.data() ?? const <String, dynamic>{};
      final summaryRaw = data['ownerAccessSummary'];
      final summary = summaryRaw is Map<String, dynamic>
          ? OwnerAccessSummary.fromMap(summaryRaw)
          : summaryRaw is Map
              ? OwnerAccessSummary.fromMap(summaryRaw.cast<String, dynamic>())
              : null;
      final ownerPendingRaw = data['ownerPending'];
      final ownerPending = ownerPendingRaw is bool
          ? ownerPendingRaw
          : ownerPendingRaw is String
              ? ownerPendingRaw.toLowerCase() == 'true'
              : null;
      final merchantId = (data['merchantId'] as String?)?.trim();
      final accessVersion = _parseAccessVersion(data['accessVersion']);

      final snapshot = _UserAccessSnapshot(
        role: (data['role'] as String?)?.trim(),
        ownerPending: ownerPending,
        merchantId: merchantId?.isEmpty == true ? null : merchantId,
        accessVersion: accessVersion,
        ownerAccessSummary: summary,
      );

      _cachedUid = uid;
      _cachedAt = now;
      _cachedSnapshot = snapshot;
      return snapshot;
    } catch (_) {
      return _cachedSnapshot ??
          const _UserAccessSnapshot(
            role: null,
            ownerPending: null,
            merchantId: null,
            accessVersion: null,
            ownerAccessSummary: null,
          );
    }
  }

  int? _parseAccessVersion(Object? rawValue) {
    if (rawValue is int && rawValue >= 0) return rawValue;
    if (rawValue is num && rawValue >= 0 && rawValue == rawValue.toInt()) {
      return rawValue.toInt();
    }
    if (rawValue is String) {
      final parsed = int.tryParse(rawValue);
      if (parsed != null && parsed >= 0) return parsed;
    }
    return null;
  }

  void forceUnauthenticated() {
    _eventVersion++;
    _cachedUid = null;
    _cachedAt = null;
    _cachedSnapshot = null;
    _lastResolvedUid = null;
    _lastTransitionSnapshot = null;
    _authState = const AuthUnauthenticated();
    notifyListeners();
  }

  /// Fuerza una relectura de token y resumen de acceso.
  Future<void> refreshSession({
    AuthSessionRefreshReason reason = AuthSessionRefreshReason.manualRetry,
    bool forceUserDocRead = false,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    await _onUserChanged(
      user,
      forceUserDocRead: forceUserDocRead,
      forcedRefreshReason: reason,
      rethrowRefreshError: true,
    );
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}

final authNotifierProvider = ChangeNotifierProvider<AuthNotifier>((ref) {
  return AuthNotifier();
});
