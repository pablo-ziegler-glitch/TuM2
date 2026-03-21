/// Estado local del borrador de onboarding OWNER.
/// Refleja OnboardingOwnerProgress de schema/types/onboarding_owner.ts.
/// La fuente de verdad es Firestore; SharedPreferences actúa como caché local.
class OnboardingDraft {
  final String draftMerchantId;
  final String currentStep;
  final Step1Data? step1;
  final Step2Data? step2;
  final bool step3Skipped;
  final DateTime createdAt;
  final DateTime expiresAt;

  const OnboardingDraft({
    required this.draftMerchantId,
    required this.currentStep,
    this.step1,
    this.step2,
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
      case 'step_1': return 1;
      case 'step_2': return 2;
      case 'step_3': return 3;
      case 'confirmation': return 4;
      default: return 1;
    }
  }

  String get savedAgoLabel {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inHours < 1) return 'hace unos minutos';
    return 'hace ${diff.inHours} hs';
  }

  String get expiresInLabel {
    if (ttlRemainingHours <= 0) return 'vencido';
    return '~${ttlRemainingHours} hs';
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

  const Step2Data({
    required this.address,
    required this.lat,
    required this.lng,
    required this.zoneId,
  });
}

class OnboardingState {
  final Step1Data? step1;
  final Step2Data? step2;
  final bool step3Skipped;
  final String currentStep;
  final OnboardingDraft? existingDraft;

  const OnboardingState({
    this.step1,
    this.step2,
    this.step3Skipped = false,
    this.currentStep = 'idle',
    this.existingDraft,
  });

  OnboardingState copyWith({
    Step1Data? step1,
    Step2Data? step2,
    bool? step3Skipped,
    String? currentStep,
    OnboardingDraft? existingDraft,
  }) {
    return OnboardingState(
      step1: step1 ?? this.step1,
      step2: step2 ?? this.step2,
      step3Skipped: step3Skipped ?? this.step3Skipped,
      currentStep: currentStep ?? this.currentStep,
      existingDraft: existingDraft ?? this.existingDraft,
    );
  }
}
