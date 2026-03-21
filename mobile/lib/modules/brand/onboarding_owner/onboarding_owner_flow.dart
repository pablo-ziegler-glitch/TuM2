import 'package:flutter/material.dart';
import 'models/onboarding_draft.dart';
import 'screens/draft_entry_screen.dart';
import 'screens/step1_tipo_nombre_screen.dart';
import 'screens/step2_direccion_screen.dart';
import 'screens/step3_horarios_screen.dart';
import 'screens/step4_confirmacion_screen.dart';

/// Orquestador del flujo de onboarding OWNER.
///
/// Gestiona la FSM local (step_1 → step_2 → step_3 → confirmation)
/// y las transiciones descritas en ONBOARDING-OWNER-FSM.md.
///
/// En producción, este widget recibe el OnboardingOwnerProgress desde
/// Firestore (vía Riverpod StreamProvider) y persiste cada transición.
/// En esta iteración se usa estado local para representar el flujo completo.
class OnboardingOwnerFlow extends StatefulWidget {
  final OnboardingDraft? existingDraft;
  final VoidCallback onComplete; // → OWNER-01
  final VoidCallback onExit;    // → HOME-01

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
  String _currentStep = 'entry'; // entry | step_1 | step_2 | step_3 | confirmation
  Step1Data? _step1;
  Step2Data? _step2;
  bool _step3Skipped = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingDraft == null) {
      _currentStep = 'step_1';
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_currentStep) {
      case 'entry':
        return DraftEntryScreen(
          draft: widget.existingDraft!,
          onResume: () => setState(() =>
              _currentStep = widget.existingDraft!.currentStep),
          onStartFresh: () => setState(() {
            _step1 = null;
            _step2 = null;
            _step3Skipped = false;
            _currentStep = 'step_1';
          }),
        );

      case 'step_1':
        return Step1TipoNombreScreen(
          initialData: _step1,
          onNext: (data) => setState(() {
            _step1 = data;
            _currentStep = 'step_2';
          }),
          onExit: widget.onExit,
        );

      case 'step_2':
        return Step2DireccionScreen(
          initialData: _step2,
          onNext: (data) => setState(() {
            _step2 = data;
            _currentStep = 'step_3';
          }),
          onBack: () => setState(() => _currentStep = 'step_1'),
          onExit: widget.onExit,
        );

      case 'step_3':
        return Step3HorariosScreen(
          onNext: () => setState(() {
            _step3Skipped = false;
            _currentStep = 'confirmation';
          }),
          onSkip: () => setState(() {
            _step3Skipped = true;
            _currentStep = 'confirmation';
          }),
          onBack: () => setState(() => _currentStep = 'step_2'),
          onExit: widget.onExit,
        );

      case 'confirmation':
        return Step4ConfirmacionScreen(
          step1: _step1!,
          step2: _step2!,
          step3Skipped: _step3Skipped,
          onBack: () => setState(() => _currentStep = 'step_3'),
          onExit: widget.onExit,
          onGoToProfile: widget.onComplete,
          onGoHome: widget.onExit,
        );

      default:
        return Step1TipoNombreScreen(
          onNext: (data) => setState(() {
            _step1 = data;
            _currentStep = 'step_2';
          }),
          onExit: widget.onExit,
        );
    }
  }
}
