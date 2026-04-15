import 'package:flutter/material.dart';

/// Estado local del borrador de onboarding OWNER.
/// Refleja OnboardingOwnerProgress de schema/types/onboarding_owner.ts.
/// La fuente de verdad es Firestore; SharedPreferences actúa como caché local.
class OnboardingDraft {
  final String draftMerchantId;
  final String currentStep;
  final Step1Data? step1;
  final Step2Data? step2;
  final List<DaySchedule>? step3;
  final bool step3Skipped;
  final DateTime createdAt;
  final DateTime expiresAt;

  const OnboardingDraft({
    required this.draftMerchantId,
    required this.currentStep,
    this.step1,
    this.step2,
    this.step3,
    this.step3Skipped = false,
    required this.createdAt,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  int get ttlRemainingHours =>
      expiresAt.difference(DateTime.now()).inHours.clamp(0, 72);

  bool get isAboutToExpire => !isExpired && ttlRemainingHours <= 6;

  double get ttlProgress => ttlRemainingHours / 72;

  List<String> get completedStepLabels {
    final labels = <String>[];
    if (step1 != null) labels.add('Nombre y categoría listos');
    if (step2 != null) labels.add('Dirección cargada');
    if (currentStep == 'confirmation' || step3Skipped) {
      labels.add(step3Skipped ? 'Horarios pendientes' : 'Horarios completados');
    }
    return labels;
  }

  int get displayStep {
    switch (currentStep) {
      case 'step_1':
        return 1;
      case 'step_2':
        return 2;
      case 'step_3':
        return 3;
      case 'confirmation':
        return 4;
      default:
        return 1;
    }
  }

  String get savedAgoLabel {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inHours < 1) return 'hace unos minutos';
    return 'hace ${diff.inHours} hs';
  }

  String get expiresInLabel {
    if (ttlRemainingHours <= 0) return 'vencido';
    return '~$ttlRemainingHours hs';
  }
}

class Step1Data {
  final String name;
  final String categoryId;

  const Step1Data({required this.name, required this.categoryId});
}

class Step2Data {
  final String address;
  final double lat;
  final double lng;
  final String zoneId;
  final String geohash;
  final String cityId;
  final String provinceId;

  const Step2Data({
    required this.address,
    required this.lat,
    required this.lng,
    required this.zoneId,
    this.geohash = '',
    this.cityId = '',
    this.provinceId = '',
  });
}

/// Horario de un día de la semana para el onboarding step 3.
class DaySchedule {
  final String day; // 'Lun', 'Mar', ... (label display)
  final String dayKey; // 'monday', 'tuesday', ... (Firestore key)
  bool enabled;
  TimeOfDay openTime;
  TimeOfDay closeTime;

  DaySchedule({
    required this.day,
    required this.dayKey,
    this.enabled = true,
    this.openTime = const TimeOfDay(hour: 9, minute: 0),
    this.closeTime = const TimeOfDay(hour: 20, minute: 0),
  });

  bool get hasTimeError =>
      enabled &&
      (closeTime.hour < openTime.hour ||
          (closeTime.hour == openTime.hour &&
              closeTime.minute <= openTime.minute));

  String get openLabel =>
      '${openTime.hour.toString().padLeft(2, '0')}:${openTime.minute.toString().padLeft(2, '0')}';

  String get closeLabel =>
      '${closeTime.hour.toString().padLeft(2, '0')}:${closeTime.minute.toString().padLeft(2, '0')}';

  /// Convierte a mapa para Firestore (schedule field en merchant_schedules).
  Map<String, dynamic> toFirestoreMap() {
    if (!enabled) {
      return {'closed': true, 'open': openLabel, 'close': closeLabel};
    }
    return {'open': openLabel, 'close': closeLabel};
  }
}

class OnboardingState {
  final Step1Data? step1;
  final Step2Data? step2;
  final List<DaySchedule>? step3;
  final bool step3Skipped;
  final String currentStep;
  final OnboardingDraft? existingDraft;

  const OnboardingState({
    this.step1,
    this.step2,
    this.step3,
    this.step3Skipped = false,
    this.currentStep = 'idle',
    this.existingDraft,
  });

  OnboardingState copyWith({
    Step1Data? step1,
    Step2Data? step2,
    List<DaySchedule>? step3,
    bool? step3Skipped,
    String? currentStep,
    OnboardingDraft? existingDraft,
  }) {
    return OnboardingState(
      step1: step1 ?? this.step1,
      step2: step2 ?? this.step2,
      step3: step3 ?? this.step3,
      step3Skipped: step3Skipped ?? this.step3Skipped,
      currentStep: currentStep ?? this.currentStep,
      existingDraft: existingDraft ?? this.existingDraft,
    );
  }
}
