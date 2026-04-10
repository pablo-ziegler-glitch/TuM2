import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/onboarding_draft.dart';

/// SL-01 — OnboardingOwnerRepository
///
/// Fuente de verdad: Firestore users/{uid}.onboardingOwnerProgress
/// Caché offline: SharedPreferences (serialización JSON)
///
/// Responsable de toda la persistencia del draft de onboarding:
/// - Leer el progreso actual
/// - Guardar cada paso al avanzar
/// - Generar y mantener el draftMerchantId
/// - Manejar ciclo de vida del draft (abandon, discard, extend TTL)
class OnboardingOwnerRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  static const String _prefsKey = 'onboarding_owner_draft';
  static const int _ttlHours = 72;

  OnboardingOwnerRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  String get _uid => _auth.currentUser!.uid;
  DocumentReference get _userRef => _firestore.doc('users/$_uid');

  // ─── Read ────────────────────────────────────────────────────────────────

  /// Stream del borrador actual desde Firestore (tiempo real).
  Stream<OnboardingDraft?> watchDraft() {
    return _userRef.snapshots().map((snap) {
      if (!snap.exists) return null;
      final progress =
          (snap.data() as Map<String, dynamic>?)?['onboardingOwnerProgress'];
      if (progress == null) return null;
      return _progressToOnboardingDraft(progress as Map<String, dynamic>);
    });
  }

  /// Lee el borrador una sola vez. Primero intenta Firestore; si falla, usa caché local.
  Future<OnboardingDraft?> getDraft() async {
    try {
      final snap = await _userRef.get();
      if (!snap.exists) return null;
      final progress =
          (snap.data() as Map<String, dynamic>?)?['onboardingOwnerProgress'];
      if (progress == null) return null;
      final draft =
          _progressToOnboardingDraft(progress as Map<String, dynamic>);
      await _cacheLocally(draft);
      return draft;
    } catch (_) {
      return _getFromCache();
    }
  }

  // ─── Write — Steps ───────────────────────────────────────────────────────

  /// Inicializa el progreso si no existe y retorna el draftMerchantId.
  Future<String> initOrGetDraftId() async {
    final snap = await _userRef.get();
    final data = snap.data() as Map<String, dynamic>?;
    final existing = data?['onboardingOwnerProgress'] as Map<String, dynamic>?;

    if (existing != null && existing['draftMerchantId'] != null) {
      return existing['draftMerchantId'] as String;
    }

    // Generate new ID using Firestore auto-ID mechanism
    final newId = _firestore.collection('_ids').doc().id;
    final now = FieldValue.serverTimestamp();

    await _userRef.set({
      'onboardingOwnerProgress': {
        'currentStep': 'step_1',
        'draftMerchantId': newId,
        'step1': null,
        'step2': null,
        'step3': null,
        'step3Skipped': false,
        'startedAt': now,
        'updatedAt': now,
      }
    }, SetOptions(merge: true));

    return newId;
  }

  /// Guarda los datos del paso 1 y avanza currentStep a 'step_2'.
  Future<void> saveStep1(Step1Data data) async {
    await _userRef.update({
      'onboardingOwnerProgress.step1': {
        'name': data.name,
        'categoryId': data.categoryId,
      },
      'onboardingOwnerProgress.currentStep': 'step_2',
      'onboardingOwnerProgress.updatedAt': FieldValue.serverTimestamp(),
    });
    await _updateCacheStep('step_2');
  }

  /// Guarda los datos del paso 2 y avanza currentStep a 'step_3'.
  Future<void> saveStep2(Step2Data data) async {
    await _userRef.update({
      'onboardingOwnerProgress.step2': {
        'address': data.address,
        'lat': data.lat,
        'lng': data.lng,
        'geohash': data.geohash,
        'zoneId': data.zoneId,
        'cityId': data.cityId,
        'provinceId': data.provinceId,
      },
      'onboardingOwnerProgress.currentStep': 'step_3',
      'onboardingOwnerProgress.updatedAt': FieldValue.serverTimestamp(),
    });
    await _updateCacheStep('step_3');
  }

  /// Guarda los horarios del paso 3 y avanza currentStep a 'confirmation'.
  Future<void> saveStep3(List<DaySchedule> schedules) async {
    final scheduleMap = <String, dynamic>{};
    for (final day in schedules) {
      if (day.enabled) {
        scheduleMap[day.dayKey] = day.toFirestoreMap();
      }
    }
    await _userRef.update({
      'onboardingOwnerProgress.step3': scheduleMap,
      'onboardingOwnerProgress.step3Skipped': false,
      'onboardingOwnerProgress.currentStep': 'confirmation',
      'onboardingOwnerProgress.updatedAt': FieldValue.serverTimestamp(),
    });
    await _updateCacheStep('confirmation');
  }

  /// Marca el paso 3 como skipped y avanza currentStep a 'confirmation'.
  Future<void> skipStep3() async {
    await _userRef.update({
      'onboardingOwnerProgress.step3Skipped': true,
      'onboardingOwnerProgress.step3': null,
      'onboardingOwnerProgress.currentStep': 'confirmation',
      'onboardingOwnerProgress.updatedAt': FieldValue.serverTimestamp(),
    });
    await _updateCacheStep('confirmation');
  }

  // ─── Write — Lifecycle ───────────────────────────────────────────────────

  /// Extiende el TTL reseteando updatedAt a ahora (72h adicionales).
  Future<void> extendTTL() async {
    await _userRef.update({
      'onboardingOwnerProgress.updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Marca el borrador como abandoned (usuario salió sin completar).
  Future<void> abandonDraft() async {
    await _userRef.update({
      'onboardingOwnerProgress.currentStep': 'abandoned',
      'onboardingOwnerProgress.updatedAt': FieldValue.serverTimestamp(),
    });
    await _updateCacheStep('abandoned');
  }

  /// Elimina completamente el onboardingOwnerProgress del documento del usuario.
  Future<void> discardDraft() async {
    await _userRef.update({
      'onboardingOwnerProgress': FieldValue.delete(),
    });
    await _clearCache();
  }

  /// Marca el onboarding como completado.
  Future<void> markCompleted() async {
    await _userRef.update({
      'onboardingOwnerProgress.currentStep': 'completed',
      'onboardingOwnerProgress.updatedAt': FieldValue.serverTimestamp(),
    });
    await _clearCache();
  }

  // ─── Cache (SharedPreferences) ───────────────────────────────────────────

  Future<void> _cacheLocally(OnboardingDraft draft) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _prefsKey,
        jsonEncode({
          'draftMerchantId': draft.draftMerchantId,
          'currentStep': draft.currentStep,
          'step3Skipped': draft.step3Skipped,
          'createdAt': draft.createdAt.toIso8601String(),
          'expiresAt': draft.expiresAt.toIso8601String(),
          if (draft.step1 != null)
            'step1': {
              'name': draft.step1!.name,
              'categoryId': draft.step1!.categoryId,
            },
          if (draft.step2 != null)
            'step2': {
              'address': draft.step2!.address,
              'lat': draft.step2!.lat,
              'lng': draft.step2!.lng,
              'geohash': draft.step2!.geohash,
              'zoneId': draft.step2!.zoneId,
              'cityId': draft.step2!.cityId,
              'provinceId': draft.step2!.provinceId,
            },
        }));
  }

  Future<OnboardingDraft?> _getFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return _mapToOnboardingDraft(map);
    } catch (_) {
      return null;
    }
  }

  Future<void> _updateCacheStep(String step) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      map['currentStep'] = step;
      await prefs.setString(_prefsKey, jsonEncode(map));
    } catch (_) {}
  }

  Future<void> _clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }

  // ─── Mappers ─────────────────────────────────────────────────────────────

  OnboardingDraft _progressToOnboardingDraft(Map<String, dynamic> progress) {
    final updatedAt =
        (progress['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final startedAt =
        (progress['startedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final expiresAt = updatedAt.add(Duration(hours: _ttlHours));

    return _mapToOnboardingDraft({
      ...progress,
      'createdAt': startedAt.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
    });
  }

  OnboardingDraft _mapToOnboardingDraft(Map<String, dynamic> map) {
    Step1Data? step1;
    if (map['step1'] != null) {
      final s1 = map['step1'] as Map<String, dynamic>;
      step1 =
          Step1Data(name: s1['name'] ?? '', categoryId: s1['categoryId'] ?? '');
    }

    Step2Data? step2;
    if (map['step2'] != null) {
      final s2 = map['step2'] as Map<String, dynamic>;
      step2 = Step2Data(
        address: s2['address'] ?? '',
        lat: (s2['lat'] as num?)?.toDouble() ?? 0,
        lng: (s2['lng'] as num?)?.toDouble() ?? 0,
        geohash: s2['geohash'] ?? '',
        zoneId: s2['zoneId'] ?? '',
        cityId: s2['cityId'] ?? '',
        provinceId: s2['provinceId'] ?? '',
      );
    }

    final createdAtStr = map['createdAt'];
    final expiresAtStr = map['expiresAt'];
    final createdAt = createdAtStr is String
        ? DateTime.tryParse(createdAtStr) ?? DateTime.now()
        : DateTime.now();
    final expiresAt = expiresAtStr is String
        ? DateTime.tryParse(expiresAtStr) ??
            DateTime.now().add(const Duration(hours: _ttlHours))
        : DateTime.now().add(const Duration(hours: _ttlHours));

    return OnboardingDraft(
      draftMerchantId: map['draftMerchantId'] ?? '',
      currentStep: map['currentStep'] ?? 'step_1',
      step1: step1,
      step2: step2,
      step3Skipped: map['step3Skipped'] == true,
      createdAt: createdAt,
      expiresAt: expiresAt,
    );
  }
}
