import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../models/onboarding_draft.dart';
import '../repositories/onboarding_owner_repository.dart';
import '../analytics/onboarding_analytics.dart';

/// Pantalla pre-step que aparece cuando hay un borrador existente.
///
/// EX-02: borrador reciente (ttlRemainingHours > 6) — tono informativo, borde azul/teal
/// EX-03: borrador por vencer (ttlRemainingHours ≤ 6) — tono warning, borde naranja
/// EX-04: borrador expirado — banner rojo, card tachada, "Registrar mi comercio"
class DraftEntryScreen extends StatelessWidget {
  final OnboardingDraft draft;
  final VoidCallback onResume;
  final VoidCallback onStartFresh;
  final OnboardingOwnerRepository ownerRepository;

  const DraftEntryScreen({
    super.key,
    required this.draft,
    required this.onResume,
    required this.onStartFresh,
    required this.ownerRepository,
  });

  Future<void> _handleResume(BuildContext context) async {
    await ownerRepository.extendTTL();
    OnboardingAnalytics.logDraftResumed();
    onResume();
  }

  Future<void> _handleDiscard(BuildContext context) async {
    await ownerRepository.discardDraft();
    OnboardingAnalytics.logDraftDiscarded();
    onStartFresh();
  }

  @override
  Widget build(BuildContext context) {
    if (draft.isExpired) {
      return _ExpiredView(
        draft: draft,
        onStartFresh: () => _handleDiscard(context),
      );
    }
    if (draft.isAboutToExpire) {
      return _ResumableView(
        draft: draft,
        onResume: () => _handleResume(context),
        onStartFresh: () => _handleDiscard(context),
        isUrgent: true,
      );
    }
    return _ResumableView(
      draft: draft,
      onResume: () => _handleResume(context),
      onStartFresh: () => _handleDiscard(context),
      isUrgent: false,
    );
  }
}

// ─── EX-02 / EX-03: borrador retomable ────────────────────────────────────────

class _ResumableView extends StatelessWidget {
  final OnboardingDraft draft;
  final VoidCallback onResume;
  final VoidCallback onStartFresh;
  final bool isUrgent;

  const _ResumableView({
    required this.draft,
    required this.onResume,
    required this.onStartFresh,
    required this.isUrgent,
  });

  @override
  Widget build(BuildContext context) {
    final progressColor =
        isUrgent ? AppColors.warningFg : AppColors.secondary500;
    final cardBorderColor =
        isUrgent ? AppColors.warningFg : AppColors.primary500;
    final cardBg = isUrgent ? AppColors.warningBg : AppColors.infoBg;
    final cardTitle = isUrgent
        ? 'Tu borrador está por vencer'
        : 'Tenés un registro sin terminar';
    final ctaLabel = isUrgent ? 'Retomar ahora' : 'Retomar registro';

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              const Text('Registrá tu comercio',
                  style: AppTextStyles.headingLg),
              const SizedBox(height: 4),
              const Text('TuM2 para dueños', style: AppTextStyles.bodySm),
              const SizedBox(height: 8),
              const Text(
                'Conectá tu comercio con los vecinos de tu zona.',
                style: AppTextStyles.bodyMd,
              ),
              const SizedBox(height: 24),

              // Draft card (EX-02 o EX-03)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBg,
                  border: Border.all(color: cardBorderColor, width: 1.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Título de la card
                    Text(
                      cardTitle,
                      style: AppTextStyles.headingSm.copyWith(
                        color: isUrgent
                            ? AppColors.warningFg
                            : AppColors.neutral900,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Mini ficha del borrador
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                draft.step1?.name ?? 'Comercio sin nombre',
                                style: AppTextStyles.headingSm,
                              ),
                              if (draft.step1 != null)
                                Text(draft.step1!.categoryId,
                                    style: AppTextStyles.bodySm),
                            ],
                          ),
                        ),
                        // Badge "Paso N de 4"
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.secondary500,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Paso ${draft.displayStep}\nde 4',
                            style: AppTextStyles.bodyXs.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Pasos completados
                    ...draft.completedStepLabels.map((label) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_outline,
                                  size: 14, color: AppColors.secondary500),
                              const SizedBox(width: 6),
                              Text(label, style: AppTextStyles.bodyXs),
                            ],
                          ),
                        )),
                    const SizedBox(height: 12),

                    // Barra de TTL
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: draft.ttlProgress,
                        backgroundColor: AppColors.neutral200,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(progressColor),
                        minHeight: 4,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Timestamp
                    Text(
                      'Guardado ${draft.savedAgoLabel} · expira en ${draft.expiresInLabel}',
                      style: AppTextStyles.bodyXs.copyWith(
                        color: isUrgent
                            ? AppColors.warningFg
                            : AppColors.neutral600,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // CTA primario dentro de la card
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: onResume,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary500,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(ctaLabel),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // CTA secundario: empezar de cero
              OutlinedButton(
                onPressed: onStartFresh,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary500,
                  side: const BorderSide(color: AppColors.primary500),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Empezar de cero'),
              ),
              const SizedBox(height: 12),

              // Footer note — crítico: retomar extiende el TTL
              const Text(
                'Al retomar, el borrador se restablece por otras 72 hs.',
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

// ─── EX-04: borrador expirado ──────────────────────────────────────────────────

class _ExpiredView extends StatelessWidget {
  final OnboardingDraft draft;
  final VoidCallback onStartFresh;

  const _ExpiredView({required this.draft, required this.onStartFresh});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Registrá tu comercio',
                  style: AppTextStyles.headingLg),
              const SizedBox(height: 4),
              const Text('TuM2 para dueños', style: AppTextStyles.bodySm),
              const SizedBox(height: 8),
              const Text(
                'Conectá tu comercio con los vecinos de tu zona.',
                style: AppTextStyles.bodyMd,
              ),
              const SizedBox(height: 24),

              // Banner rojo "Tu borrador venció"
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.errorBg,
                  border: Border.all(
                      color: AppColors.errorFg.withValues(alpha: 0.4)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        color: AppColors.errorFg, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Tu borrador venció',
                      style: AppTextStyles.labelSm.copyWith(
                        color: AppColors.errorFg,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Card tachada con badge "Expirado"
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.neutral100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.neutral300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            draft.step1?.name ?? 'Comercio',
                            style: AppTextStyles.headingSm.copyWith(
                              color: AppColors.neutral500,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.neutral300,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Expirado',
                            style: AppTextStyles.bodyXs
                                .copyWith(color: AppColors.neutral700),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Venció ${draft.savedAgoLabel} · datos eliminados',
                      style: AppTextStyles.bodyXs
                          .copyWith(color: AppColors.neutral500),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Texto explicativo sin dramatismo
              const Text(
                'Los borradores se guardan por 72 hs. Podés registrar tu comercio cuando quieras.',
                style: AppTextStyles.bodySm,
              ),
              const SizedBox(height: 24),

              // CTA primario — framing positivo
              ElevatedButton(
                onPressed: onStartFresh,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary500,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Registrar mi comercio'),
              ),
              const SizedBox(height: 12),

              // Footer — reduce barrera de re-entrada
              const Text(
                'El proceso toma menos de 5 minutos.',
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
