import 'dart:async';

import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../models/onboarding_draft.dart';
import '../services/onboarding_owner_submit_service.dart';
import '../analytics/onboarding_analytics.dart';
import '../widgets/step_indicator.dart';
import '../widgets/exit_modal.dart';

/// ONBOARDING-OWNER-04 — Paso 4: Confirmación y activación
///
/// Estados:
///   Normal          — resumen completo, CTA "Publicar mi comercio"
///   EX-12           — horarios no cargados (step3Skipped: true) → badge naranja + warning
///   EX-05           — publicando (loading full-screen, no interrumpible)
///   EX-06           — éxito (comercio enviado, "¿Qué pasa ahora?")
///   EX-07           — error de red al publicar (banner + retry, datos guardados)
enum _PublishState { idle, loading, success, networkError }

class Step4ConfirmacionScreen extends StatefulWidget {
  final Step1Data step1;
  final Step2Data step2;
  final bool step3Skipped;
  final String draftMerchantId;
  final OnboardingOwnerSubmitService submitService;
  final VoidCallback onBack;
  final VoidCallback onExit;
  final VoidCallback onGoToProfile; // EX-06 → OWNER-01
  final VoidCallback onGoHome; // EX-06 → HOME-01

  const Step4ConfirmacionScreen({
    super.key,
    required this.step1,
    required this.step2,
    required this.step3Skipped,
    required this.draftMerchantId,
    required this.submitService,
    required this.onBack,
    required this.onExit,
    required this.onGoToProfile,
    required this.onGoHome,
  });

  @override
  State<Step4ConfirmacionScreen> createState() =>
      _Step4ConfirmacionScreenState();
}

class _Step4ConfirmacionScreenState extends State<Step4ConfirmacionScreen> {
  _PublishState _publishState = _PublishState.idle;
  StreamSubscription<SubmitState>? _submitSubscription;

  @override
  void initState() {
    super.initState();
    // Suscribir al stream del submit service
    _submitSubscription = widget.submitService.stateStream.listen((state) {
      if (!mounted) return;
      setState(() {
        switch (state) {
          case SubmitState.loading:
            _publishState = _PublishState.loading;
          case SubmitState.success:
            _publishState = _PublishState.success;
            OnboardingAnalytics.logCompleted();
          case SubmitState.networkError:
            _publishState = _PublishState.networkError;
            OnboardingAnalytics.logError(
                'confirmation', 'submit_network_error');
          case SubmitState.idle:
            _publishState = _PublishState.idle;
        }
      });
    });
  }

  @override
  void dispose() {
    _submitSubscription?.cancel();
    super.dispose();
  }

  Future<void> _onPublish() async {
    OnboardingAnalytics.logSubmitted();
    await widget.submitService.submit(widget.draftMerchantId);
  }

  Future<void> _onExitTap() async {
    final action = await showExitModal(context);
    if (action == ExitAction.saveDraft || action == ExitAction.discard) {
      widget.onExit();
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_publishState) {
      case _PublishState.loading:
        return _LoadingView(); // EX-05
      case _PublishState.success:
        return _SuccessView(
          // EX-06
          merchantName: widget.step1.name,
          onGoToProfile: widget.onGoToProfile,
          onGoHome: widget.onGoHome,
        );
      case _PublishState.networkError:
      case _PublishState.idle:
        return _ConfirmView(
          step1: widget.step1,
          step2: widget.step2,
          step3Skipped: widget.step3Skipped,
          hasNetworkError: _publishState == _PublishState.networkError,
          onPublish: _onPublish,
          onBack: widget.onBack,
          onExit: _onExitTap,
          onLoadSchedules: widget.onBack, // volver a paso 3
        );
    }
  }
}

// ─── Vista de confirmación (Normal + EX-12 + EX-07) ───────────────────────────

class _ConfirmView extends StatelessWidget {
  final Step1Data step1;
  final Step2Data step2;
  final bool step3Skipped;
  final bool hasNetworkError;
  final VoidCallback onPublish;
  final VoidCallback onBack;
  final VoidCallback onExit;
  final VoidCallback onLoadSchedules;

  const _ConfirmView({
    required this.step1,
    required this.step2,
    required this.step3Skipped,
    required this.hasNetworkError,
    required this.onPublish,
    required this.onBack,
    required this.onExit,
    required this.onLoadSchedules,
  });

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
                    child: Text('¡Casi listo!', style: AppTextStyles.headingMd),
                  ),
                  IconButton(
                    onPressed: onExit,
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
                child: Text('Paso 4 de 4', style: AppTextStyles.bodySm),
              ),
            ),
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: StepIndicator(currentStep: 4),
            ),
            const SizedBox(height: 20),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // EX-07: banner de error de red
                    if (hasNetworkError) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.errorBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppColors.errorFg.withOpacity(0.3)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.error_outline,
                                color: AppColors.errorFg, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'No se pudo publicar',
                                    style: AppTextStyles.labelSm.copyWith(
                                      color: AppColors.errorFg,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Problema de conexión. Tus datos están guardados — intentá cuando tengas red.',
                                    style: AppTextStyles.bodyXs
                                        .copyWith(color: AppColors.errorFg),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Card resumen del comercio
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.neutral200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(step1.name, style: AppTextStyles.headingMd),
                          const SizedBox(height: 8),
                          _SummaryRow(
                            icon: Icons.store_outlined,
                            text: step1.categoryId,
                          ),
                          _SummaryRow(
                            icon: Icons.location_on_outlined,
                            text: step2.address,
                          ),
                          _SummaryRow(
                            icon: Icons.public_outlined,
                            text: 'Zona: ${step2.zoneId}',
                            isGreen: true,
                          ),
                          // EX-12: Horarios pendientes
                          _SummaryRow(
                            icon: Icons.schedule_outlined,
                            text:
                                step3Skipped ? '' : '9:00 – 20:00 (Lun a Vie)',
                            trailingBadge:
                                step3Skipped ? const _PendingBadge() : null,
                          ),
                        ],
                      ),
                    ),

                    // EX-12: warning "Horarios no cargados"
                    if (step3Skipped) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.warningBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppColors.warningFg.withOpacity(0.4)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.warning_amber_rounded,
                                color: AppColors.warningFg, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Horarios no cargados',
                                    style: AppTextStyles.labelSm.copyWith(
                                      color: AppColors.warningFg,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    "Los vecinos verán 'consultar horarios' hasta que los cargues desde tu perfil.",
                                    style: AppTextStyles.bodyXs
                                        .copyWith(color: AppColors.warningFg),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

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
                  // EX-07: "Reintentar" en lugar de "Publicar"
                  // EX-12: "Publicar igual" (misma prominencia)
                  ElevatedButton(
                    onPressed: onPublish,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary500,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(hasNetworkError
                        ? 'Reintentar'
                        : step3Skipped
                            ? 'Publicar igual'
                            : 'Publicar mi comercio'),
                  ),

                  // EX-12: "Cargar horarios ahora" — mismo peso visual (outline, no texto puro)
                  if (step3Skipped && !hasNetworkError) ...[
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: onLoadSchedules,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary500,
                        side: const BorderSide(color: AppColors.primary500),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Cargar horarios ahora'),
                    ),
                  ],

                  // EX-07: footer + "Intentar más tarde"
                  if (hasNetworkError) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Tus datos están guardados localmente.',
                      style: AppTextStyles.bodyXs,
                      textAlign: TextAlign.center,
                    ),
                    TextButton(
                      onPressed: () {}, // → HOME-01 sin limpiar draft
                      style: TextButton.styleFrom(
                          foregroundColor: AppColors.neutral700),
                      child: const Text('Intentar más tarde'),
                    ),
                  ],

                  if (!hasNetworkError && !step3Skipped) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Tu comercio será revisado y estará visible en breve.',
                      style: AppTextStyles.bodyXs,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── EX-05: Loading ────────────────────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const CircularProgressIndicator(
                color: AppColors.primary500,
                strokeWidth: 3,
              ),
              const SizedBox(height: 32),
              Text(
                'Publicando tu comercio...',
                style: AppTextStyles.headingMd,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Esto tarda solo unos segundos',
                style: AppTextStyles.bodySm,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Skeleton card — técnica de percepción de progreso
              _SkeletonCard(),

              const SizedBox(height: 32),
              Text(
                'No cerrés la app mientras procesamos',
                style: AppTextStyles.bodyXs,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.neutral100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SkeletonLine(width: 0.6),
          const SizedBox(height: 10),
          _SkeletonLine(width: 0.4),
          const SizedBox(height: 8),
          _SkeletonLine(width: 0.8),
        ],
      ),
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  final double width;
  const _SkeletonLine({required this.width});

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: width,
      child: Container(
        height: 14,
        decoration: BoxDecoration(
          color: AppColors.neutral300,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}

// ─── EX-06: Éxito ─────────────────────────────────────────────────────────────

class _SuccessView extends StatelessWidget {
  final String merchantName;
  final VoidCallback onGoToProfile;
  final VoidCallback onGoHome;

  const _SuccessView({
    required this.merchantName,
    required this.onGoToProfile,
    required this.onGoHome,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),

              // Checkmark en círculo verde
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    color: AppColors.successBg,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(Icons.check_rounded,
                        color: AppColors.successFg, size: 36),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Text('¡Comercio enviado!',
                  style: AppTextStyles.headingLg, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                '$merchantName está en revisión. Te avisamos cuando esté visible.',
                style: AppTextStyles.bodySm,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Bloque "¿Qué pasa ahora?" — reduce ansiedad post-submit
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.infoBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('¿Qué pasa ahora?',
                        style: AppTextStyles.headingSm
                            .copyWith(color: AppColors.primary500)),
                    const SizedBox(height: 12),
                    _NextStep(
                        number: '1',
                        text: 'Revisamos tu comercio (hasta 24 hs)'),
                    _NextStep(
                        number: '2',
                        text: 'Te notificamos por email cuando esté activo'),
                    _NextStep(
                        number: '3',
                        text: 'Podés editar datos desde tu perfil'),
                  ],
                ),
              ),

              const Spacer(),

              ElevatedButton(
                onPressed: onGoToProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary500,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Ir a mi perfil de comercio'),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: onGoHome,
                style:
                    TextButton.styleFrom(foregroundColor: AppColors.neutral700),
                child: const Text('Volver al inicio'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NextStep extends StatelessWidget {
  final String number;
  final String text;
  const _NextStep({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: const BoxDecoration(
              color: AppColors.primary500,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(number,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: AppTextStyles.bodySm)),
        ],
      ),
    );
  }
}

// ─── Helpers compartidos ───────────────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool isGreen;
  final Widget? trailingBadge;

  const _SummaryRow({
    required this.icon,
    required this.text,
    this.isGreen = false,
    this.trailingBadge,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: isGreen ? AppColors.secondary500 : AppColors.neutral500,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodySm.copyWith(
                color: isGreen ? AppColors.secondary500 : AppColors.neutral800,
              ),
            ),
          ),
          if (trailingBadge != null) trailingBadge!,
        ],
      ),
    );
  }
}

class _PendingBadge extends StatelessWidget {
  const _PendingBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.warningBg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.warningFg.withOpacity(0.5)),
      ),
      child: Text(
        'Pendiente',
        style: AppTextStyles.bodyXs.copyWith(
          color: AppColors.warningFg,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
