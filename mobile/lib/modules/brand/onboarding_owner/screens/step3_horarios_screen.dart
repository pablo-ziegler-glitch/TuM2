import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../widgets/step_indicator.dart';
import '../widgets/exit_modal.dart';
import '../widgets/schedule_row.dart';

/// ONBOARDING-OWNER-03 — Paso 3: Horarios iniciales
///
/// Estados:
///   Normal     — grilla de días con toggles + time pickers
///   EX-11      — cierre antes de apertura en algún día → borde rojo + error inline en esa fila
///
/// El usuario puede skipear con "Completar después" (step3Skipped: true).
class Step3HorariosScreen extends StatefulWidget {
  final VoidCallback onNext; // SAVE_STEP_3
  final VoidCallback onSkip; // SKIP_STEP_3
  final VoidCallback onBack;
  final VoidCallback onExit;

  const Step3HorariosScreen({
    super.key,
    required this.onNext,
    required this.onSkip,
    required this.onBack,
    required this.onExit,
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
      DaySchedule(day: 'Lun', openTime: const TimeOfDay(hour: 9, minute: 0),  closeTime: const TimeOfDay(hour: 20, minute: 0)),
      DaySchedule(day: 'Mar', openTime: const TimeOfDay(hour: 18, minute: 0), closeTime: const TimeOfDay(hour: 8, minute: 0)),  // EX-11: error precargado
      DaySchedule(day: 'Mié', openTime: const TimeOfDay(hour: 9, minute: 0),  closeTime: const TimeOfDay(hour: 20, minute: 0)),
      DaySchedule(day: 'Jue', openTime: const TimeOfDay(hour: 9, minute: 0),  closeTime: const TimeOfDay(hour: 20, minute: 0)),
      DaySchedule(day: 'Vie', openTime: const TimeOfDay(hour: 9, minute: 0),  closeTime: const TimeOfDay(hour: 21, minute: 0)),
      DaySchedule(day: 'Sáb', openTime: const TimeOfDay(hour: 10, minute: 0), closeTime: const TimeOfDay(hour: 14, minute: 0)),
      DaySchedule(day: 'Dom', enabled: false, openTime: const TimeOfDay(hour: 9, minute: 0), closeTime: const TimeOfDay(hour: 20, minute: 0)),
    ];
  }

  bool get _hasAnyError => _schedules.any((s) => s.hasTimeError);
  bool get _hasAtLeastOneActive => _schedules.any((s) => s.enabled);

  bool get _canContinue => _hasAtLeastOneActive && !_hasAnyError;

  Future<void> _onExitTap() async {
    final action = await showExitModal(context);
    if (action == ExitAction.saveDraft || action == ExitAction.discard) {
      widget.onExit();
    }
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
                    onPressed: _canContinue ? widget.onNext : null,
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
                    onPressed: widget.onSkip,
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
