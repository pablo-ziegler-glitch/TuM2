import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../models/onboarding_draft.dart';
import '../repositories/onboarding_owner_repository.dart';
import '../widgets/step_indicator.dart';
import '../widgets/exit_modal.dart';
import '../widgets/schedule_row.dart';
import '../analytics/onboarding_analytics.dart';

/// ONBOARDING-OWNER-03 — Paso 3: Horarios iniciales
///
/// Estados:
///   Normal     — grilla de días con toggles + time pickers
///   EX-11      — cierre antes de apertura en algún día → borde rojo + error inline en esa fila
///
/// El usuario puede skipear con "Completar después" (step3Skipped: true).
class Step3HorariosScreen extends StatefulWidget {
  final ValueChanged<List<DaySchedule>> onNext; // SAVE_STEP_3
  final VoidCallback onSkip;                    // SKIP_STEP_3
  final VoidCallback onBack;
  final VoidCallback onExit;
  final OnboardingOwnerRepository ownerRepository;

  const Step3HorariosScreen({
    super.key,
    required this.onNext,
    required this.onSkip,
    required this.onBack,
    required this.onExit,
    required this.ownerRepository,
  });

  @override
  State<Step3HorariosScreen> createState() => _Step3HorariosScreenState();
}

class _Step3HorariosScreenState extends State<Step3HorariosScreen> {
  late final List<DaySchedule> _schedules;

  @override
  void initState() {
    super.initState();
    _schedules = [
      DaySchedule(day: 'Lun', dayKey: 'monday',    openTime: const TimeOfDay(hour: 9,  minute: 0), closeTime: const TimeOfDay(hour: 20, minute: 0)),
      DaySchedule(day: 'Mar', dayKey: 'tuesday',   openTime: const TimeOfDay(hour: 9,  minute: 0), closeTime: const TimeOfDay(hour: 20, minute: 0)),
      DaySchedule(day: 'Mié', dayKey: 'wednesday', openTime: const TimeOfDay(hour: 9,  minute: 0), closeTime: const TimeOfDay(hour: 20, minute: 0)),
      DaySchedule(day: 'Jue', dayKey: 'thursday',  openTime: const TimeOfDay(hour: 9,  minute: 0), closeTime: const TimeOfDay(hour: 20, minute: 0)),
      DaySchedule(day: 'Vie', dayKey: 'friday',    openTime: const TimeOfDay(hour: 9,  minute: 0), closeTime: const TimeOfDay(hour: 21, minute: 0)),
      DaySchedule(day: 'Sáb', dayKey: 'saturday',  openTime: const TimeOfDay(hour: 10, minute: 0), closeTime: const TimeOfDay(hour: 14, minute: 0)),
      DaySchedule(day: 'Dom', dayKey: 'sunday',    enabled: false, openTime: const TimeOfDay(hour: 9, minute: 0), closeTime: const TimeOfDay(hour: 20, minute: 0)),
    ];
  }

  bool get _hasAnyError => _schedules.any((s) => s.hasTimeError);
  bool get _hasAtLeastOneActive => _schedules.any((s) => s.enabled);

  bool get _canContinue => _hasAtLeastOneActive && !_hasAnyError;

  Future<void> _onExitTap() async {
    final action = await showExitModal(context);
    if (action == ExitAction.saveDraft) {
      await widget.ownerRepository.abandonDraft();
      OnboardingAnalytics.logExited('step_3');
      widget.onExit();
    } else if (action == ExitAction.discard) {
      await widget.ownerRepository.discardDraft();
      OnboardingAnalytics.logDraftDiscarded();
      widget.onExit();
    }
  }

  Future<void> _onSave() async {
    if (!_canContinue) return;
    try {
      await widget.ownerRepository.saveStep3(_schedules);
    } catch (_) {
      // Error de red: continuar de todos modos (se guardará en el submit)
    }
    widget.onNext(_schedules);
  }

  Future<void> _onSkip() async {
    try {
      await widget.ownerRepository.skipStep3();
    } catch (_) {}
    widget.onSkip();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text('¿Cuándo abrís?', style: AppTextStyles.headingMd),
                  ),
                  IconButton(
                    onPressed: _onExitTap,
                    icon: const Icon(Icons.close),
                    color: AppColors.neutral700,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Paso 3 de 4', style: AppTextStyles.bodySm),
              ),
            ),
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: StepIndicator(currentStep: 3),
            ),
            const SizedBox(height: 20),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Filas por día
                    ..._schedules.asMap().entries.map((entry) {
                      final i = entry.key;
                      final s = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: ScheduleRow(
                          schedule: s,
                          onToggle: (enabled) =>
                              setState(() => _schedules[i].enabled = enabled),
                          onOpenChanged: (t) =>
                              setState(() => _schedules[i].openTime = t),
                          onCloseChanged: (t) =>
                              setState(() => _schedules[i].closeTime = t),
                        ),
                      );
                    }),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),

            // ── Footer ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton(
                    onPressed: _canContinue ? _onSave : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary500,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.neutral300,
                      disabledForegroundColor: AppColors.neutral600,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Guardar y continuar'),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: _onSkip,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.neutral700,
                    ),
                    child: const Text('Completar después'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
