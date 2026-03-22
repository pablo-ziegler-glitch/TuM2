import 'package:flutter/material.dart';
import 'models/onboarding_draft.dart';
import 'repositories/onboarding_owner_repository.dart';
import 'repositories/categories_repository.dart';
import 'services/onboarding_owner_submit_service.dart';
import 'services/google_places_service.dart';
import 'services/duplicate_check_service.dart';
import 'analytics/onboarding_analytics.dart';
import 'screens/draft_entry_screen.dart';
import 'screens/step1_tipo_nombre_screen.dart';
import 'screens/step2_direccion_screen.dart';
import 'screens/step3_horarios_screen.dart';
import 'screens/step4_confirmacion_screen.dart';

/// Orquestador del flujo de onboarding OWNER.
///
/// Gestiona la FSM (step_1 → step_2 → step_3 → confirmation → submitted)
/// según ONBOARDING-OWNER-FSM.md.
///
/// Crea y posee todos los servicios/repositorios del flujo.
/// Persiste cada transición en Firestore vía [OnboardingOwnerRepository].
class OnboardingOwnerFlow extends StatefulWidget {
  final OnboardingDraft? existingDraft;
  final VoidCallback onComplete;  // → OWNER-01
  final VoidCallback onExit;      // → HOME-01

  const OnboardingOwnerFlow({
    super.key,
    this.existingDraft,
    required this.onComplete,
    required this.onExit,
  });

  @override
  State<OnboardingOwnerFlow> createState() => _OnboardingOwnerFlowState();
}

class _OnboardingOwnerFlowState extends State<OnboardingOwnerFlow> {
  // ── Services ──────────────────────────────────────────────────────────────
  late final OnboardingOwnerRepository _repository;
  late final CategoriesRepository _categoriesRepository;
  late final GooglePlacesService _placesService;
  late final DuplicateCheckService _duplicateCheckService;
  late final OnboardingOwnerSubmitService _submitService;

  // ── FSM state ─────────────────────────────────────────────────────────────
  String _currentStep = 'entry';
  Step1Data? _step1;
  Step2Data? _step2;
  List<DaySchedule>? _step3;
  bool _step3Skipped = false;
  String _draftMerchantId = '';

  @override
  void initState() {
    super.initState();
    _repository = OnboardingOwnerRepository();
    _categoriesRepository = CategoriesRepository();
    _placesService = GooglePlacesService();
    _duplicateCheckService = DuplicateCheckService();
    _submitService = OnboardingOwnerSubmitService(repository: _repository);

    _initFlow();
  }

  Future<void> _initFlow() async {
    if (widget.existingDraft != null) {
      // Hay un borrador existente → mostrar pantalla entry
      _currentStep = 'entry';
    } else {
      // Flujo nuevo → inicializar draft en Firestore y empezar step_1
      try {
        _draftMerchantId = await _repository.initOrGetDraftId();
      } catch (_) {
        // Si falla Firestore, usar ID temporal; se sincronizará luego
        _draftMerchantId = DateTime.now().millisecondsSinceEpoch.toString();
      }
      if (mounted) {
        setState(() => _currentStep = 'step_1');
        OnboardingAnalytics.logStarted();
      }
    }
  }

  @override
  void dispose() {
    _duplicateCheckService.dispose();
    _submitService.dispose();
    super.dispose();
  }

  /// Llamado por las pantallas que gestionan su propio exit modal (step1, step2, step3).
  /// Para step4, el exit se delega directamente al widget.onExit sin abandon
  /// porque el modal ya maneja las opciones.
  void _onFlowExit() => widget.onExit();

  @override
  Widget build(BuildContext context) {
    switch (_currentStep) {
      case 'entry':
        return DraftEntryScreen(
          draft: widget.existingDraft!,
          ownerRepository: _repository,
          onResume: () async {
            final draft = widget.existingDraft!;
            _draftMerchantId = draft.draftMerchantId;
            _step1 = draft.step1;
            _step2 = draft.step2;
            _step3Skipped = draft.step3Skipped;
            setState(() => _currentStep = draft.currentStep);
          },
          onStartFresh: () async {
            _draftMerchantId = await _repository.initOrGetDraftId();
            setState(() {
              _step1 = null;
              _step2 = null;
              _step3 = null;
              _step3Skipped = false;
              _currentStep = 'step_1';
            });
            OnboardingAnalytics.logStarted();
          },
        );

      case 'step_1':
        return Step1TipoNombreScreen(
          initialData: _step1,
          ownerRepository: _repository,
          categoriesRepository: _categoriesRepository,
          duplicateCheckService: _duplicateCheckService,
          onNext: (data) {
            setState(() {
              _step1 = data;
              _currentStep = 'step_2';
            });
            OnboardingAnalytics.logStepCompleted('step_1');
          },
          onExit: widget.onExit,
        );

      case 'step_2':
        return Step2DireccionScreen(
          initialData: _step2,
          ownerRepository: _repository,
          placesService: _placesService,
          onNext: (data) {
            setState(() {
              _step2 = data;
              _currentStep = 'step_3';
            });
            OnboardingAnalytics.logStepCompleted('step_2');
          },
          onBack: () => setState(() => _currentStep = 'step_1'),
          onExit: widget.onExit,
        );

      case 'step_3':
        return Step3HorariosScreen(
          ownerRepository: _repository,
          onNext: (schedules) {
            setState(() {
              _step3 = schedules;
              _step3Skipped = false;
              _currentStep = 'confirmation';
            });
            OnboardingAnalytics.logStepCompleted('step_3');
          },
          onSkip: () {
            setState(() {
              _step3Skipped = true;
              _currentStep = 'confirmation';
            });
            OnboardingAnalytics.logStep3Skipped();
          },
          onBack: () => setState(() => _currentStep = 'step_2'),
          onExit: widget.onExit,
        );

      case 'confirmation':
        return Step4ConfirmacionScreen(
          step1: _step1!,
          step2: _step2!,
          step3Skipped: _step3Skipped,
          draftMerchantId: _draftMerchantId,
          submitService: _submitService,
          onBack: () => setState(() => _currentStep = 'step_3'),
          onExit: widget.onExit,
          onGoToProfile: widget.onComplete,
          onGoHome: widget.onExit,
        );

      default:
        return Step1TipoNombreScreen(
          ownerRepository: _repository,
          categoriesRepository: _categoriesRepository,
          duplicateCheckService: _duplicateCheckService,
          onNext: (data) {
            setState(() {
              _step1 = data;
              _currentStep = 'step_2';
            });
          },
          onExit: widget.onExit,
        );
    }
  }
}
