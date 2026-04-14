import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_state.dart';
import '../../../core/providers/feature_flags_provider.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../analytics/owner_dashboard_analytics.dart';
import '../application/owner_dashboard_logic.dart';
import '../models/owner_merchant_summary.dart';
import '../providers/owner_providers.dart';

/// OWNER-01 — Pantalla base "Mi comercio" para OWNER.
class OwnerPanelScreen extends ConsumerStatefulWidget {
  const OwnerPanelScreen({super.key});

  @override
  ConsumerState<OwnerPanelScreen> createState() => _OwnerPanelScreenState();
}

/// Alias explícito para la nomenclatura sugerida de la tarjeta.
class OwnerDashboardPage extends OwnerPanelScreen {
  const OwnerDashboardPage({super.key});
}

class _OwnerPanelScreenState extends ConsumerState<OwnerPanelScreen> {
  String? _lastViewedMerchantId;
  bool _errorEventLogged = false;
  bool _emptyEventLogged = false;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(ownerAuthStateProvider);
    final isAdminSession =
        authState is AuthAuthenticated ? _isAdminRole(authState.role) : false;

    if (isAdminSession) {
      return Scaffold(
        backgroundColor: AppColors.neutral50,
        appBar: AppBar(
          backgroundColor: AppColors.neutral50,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: CloseButton(
            color: AppColors.neutral900,
            onPressed: () {
              if (context.canPop()) {
                context.pop();
                return;
              }
              context.go(AppRoutes.profile);
            },
          ),
          title: const Text('Mi comercio', style: AppTextStyles.headingSm),
        ),
        body: const _AdminOwnerDashboard(),
      );
    }

    if (authState is! AuthAuthenticated) {
      return const _OwnerDashboardScaffold(
        body: _OwnerDashboardUnauthorized(
          message: 'Necesitás iniciar sesión para usar este panel.',
        ),
      );
    }

    if (authState.role != 'owner') {
      return const _OwnerDashboardScaffold(
        body: _OwnerDashboardUnauthorized(
          message: 'Este panel es exclusivo para dueños de comercios.',
        ),
      );
    }

    final dashboardEnabledAsync = ref.watch(ownerDashboardEnabledProvider);
    if (dashboardEnabledAsync.isLoading) {
      return const _OwnerDashboardScaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary500),
        ),
      );
    }
    if (dashboardEnabledAsync.hasError ||
        (dashboardEnabledAsync.valueOrNull ?? true) == false) {
      return const _OwnerDashboardScaffold(
        body: _OwnerDashboardUnauthorized(
          message:
              'El panel OWNER no está disponible en este momento. Intentá nuevamente más tarde.',
        ),
      );
    }

    if (authState.ownerPending) {
      return const _OwnerDashboardScaffold(
        body: _OwnerReviewPendingDashboard(),
      );
    }

    final ownerMerchantAsync = ref.watch(ownerMerchantProvider);

    return _OwnerDashboardScaffold(
      body: ownerMerchantAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary500),
        ),
        error: (_, __) {
          if (!_errorEventLogged) {
            _errorEventLogged = true;
            unawaited(OwnerDashboardAnalytics.logErrorViewed());
          }
          return _OwnerDashboardError(
            onRetry: () => ref.invalidate(ownerMerchantProvider),
          );
        },
        data: (resolution) {
          _errorEventLogged = false;
          if (!resolution.hasMerchant) {
            if (!_emptyEventLogged) {
              _emptyEventLogged = true;
              unawaited(OwnerDashboardAnalytics.logEmptyStateViewed());
            }
            return const _OwnerDashboardNoMerchant();
          }
          _emptyEventLogged = false;
          final merchant = resolution.primaryMerchant!;
          if (_lastViewedMerchantId != merchant.id) {
            _lastViewedMerchantId = merchant.id;
            unawaited(
                OwnerDashboardAnalytics.logViewed(merchantId: merchant.id));
          }

          return _OwnerDashboardBody(
            merchant: merchant,
            hasMultipleMerchants: resolution.hasMultipleMerchants,
            ownerPending: authState.ownerPending,
          );
        },
      ),
    );
  }
}

class _OwnerDashboardScaffold extends StatelessWidget {
  const _OwnerDashboardScaffold({required this.body});

  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.neutral50,
      appBar: AppBar(
        backgroundColor: AppColors.neutral50,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: CloseButton(
          color: AppColors.neutral900,
          onPressed: () {
            if (context.canPop()) {
              context.pop();
              return;
            }
            context.go(AppRoutes.profile);
          },
        ),
        title: const Text('Mi comercio', style: AppTextStyles.headingSm),
      ),
      body: body,
    );
  }
}

class _AdminOwnerDashboard extends StatelessWidget {
  const _AdminOwnerDashboard();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.infoBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.primary200),
          ),
          child: Text(
            'Vista OWNER en modo administración. No requiere comercio asociado al admin.',
            style: AppTextStyles.bodySm.copyWith(color: AppColors.primary700),
          ),
        ),
        const SizedBox(height: 14),
        const _AdminOwnerActionCard(
          title: 'Gestionar Productos',
          route: AppRoutes.ownerProducts,
          icon: Icons.inventory_2_outlined,
        ),
        const SizedBox(height: 10),
        const _AdminOwnerActionCard(
          title: 'Editar Horarios',
          route: AppRoutes.ownerSchedules,
          icon: Icons.schedule_outlined,
        ),
        const SizedBox(height: 10),
        const _AdminOwnerActionCard(
          title: 'Señales Operativas',
          route: AppRoutes.ownerSignals,
          icon: Icons.campaign_outlined,
        ),
        const SizedBox(height: 10),
        const _AdminOwnerActionCard(
          title: 'Turnos de farmacia',
          route: AppRoutes.ownerPharmacyDuties,
          icon: Icons.medical_services_outlined,
        ),
      ],
    );
  }
}

class _AdminOwnerActionCard extends StatelessWidget {
  const _AdminOwnerActionCard({
    required this.title,
    required this.route,
    required this.icon,
  });

  final String title;
  final String route;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => context.push(route),
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.neutral100),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.primary50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.primary600),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(title, style: AppTextStyles.labelMd),
            ),
            const Icon(Icons.chevron_right, color: AppColors.neutral500),
          ],
        ),
      ),
    );
  }
}

class _OwnerDashboardUnauthorized extends StatelessWidget {
  const _OwnerDashboardUnauthorized({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline,
                size: 34, color: AppColors.neutral600),
            const SizedBox(height: 12),
            const Text(
              'Acceso no permitido',
              style: AppTextStyles.headingSm,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: AppTextStyles.bodySm,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            OutlinedButton(
              onPressed: () => context.go(AppRoutes.profile),
              child: const Text('Volver a Perfil'),
            ),
          ],
        ),
      ),
    );
  }
}

class _OwnerReviewPendingDashboard extends StatelessWidget {
  const _OwnerReviewPendingDashboard();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.warningBg,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(
                  'PENDIENTE',
                  style: AppTextStyles.labelSm.copyWith(
                    color: AppColors.tertiary700,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Estamos revisando tu comercio',
                style: AppTextStyles.headingMd,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Nuestro equipo de soporte está validando tus datos. Recibirás una notificación en cuanto esté listo.',
                style:
                    AppTextStyles.bodySm.copyWith(color: AppColors.neutral700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.schedule,
                    size: 14,
                    color: AppColors.neutral600,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Tiempo estimado: 24 - 48 horas',
                    style: AppTextStyles.bodyXs.copyWith(
                      color: AppColors.neutral600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Text(
              'ACCIONES RÁPIDAS',
              style: AppTextStyles.labelSm.copyWith(
                color: AppColors.neutral600,
                letterSpacing: 1,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.neutral100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'MODO LECTURA',
                style:
                    AppTextStyles.bodyXs.copyWith(color: AppColors.neutral600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const _ReadOnlyQuickActions(),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.infoBg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '¿Necesitás ayuda con tu registro?',
                style:
                    AppTextStyles.labelMd.copyWith(color: AppColors.primary700),
              ),
              const SizedBox(height: 4),
              Text(
                'Si tenés dudas sobre documentos requeridos, revisá nuestra guía rápida de validación.',
                style:
                    AppTextStyles.bodySm.copyWith(color: AppColors.primary700),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => context.go(AppRoutes.profile),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Ver guía'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OwnerDashboardNoMerchant extends StatelessWidget {
  const _OwnerDashboardNoMerchant();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.storefront_outlined,
              size: 34,
              color: AppColors.neutral600,
            ),
            const SizedBox(height: 12),
            const Text(
              'Todavía no tenés un comercio vinculado',
              style: AppTextStyles.headingSm,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Necesitás vincular o reclamar un comercio para empezar a gestionarlo.',
              style: AppTextStyles.bodySm,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () => context.go(AppRoutes.onboardingOwner),
              icon: const Icon(Icons.add_business_outlined),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary500,
                foregroundColor: Colors.white,
              ),
              label: const Text('Vincular comercio'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => context.go(AppRoutes.onboardingOwner),
              child: const Text('¿Tu comercio ya existe? Reclamar ahora'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadOnlyQuickActions extends StatelessWidget {
  const _ReadOnlyQuickActions();

  @override
  Widget build(BuildContext context) {
    const actions = <({IconData icon, String title, String subtitle})>[
      (
        icon: Icons.inventory_2_outlined,
        title: 'Productos',
        subtitle: 'Gestionar catálogo de inventario',
      ),
      (
        icon: Icons.payments_outlined,
        title: 'Finanzas',
        subtitle: 'Ver ingresos y reportes',
      ),
      (
        icon: Icons.settings_suggest_outlined,
        title: 'Ajustes',
        subtitle: 'Configuración del comercio',
      ),
      (
        icon: Icons.support_agent_outlined,
        title: 'Soporte',
        subtitle: 'Hablar con nuestro equipo',
      ),
    ];
    return Column(
      children: actions
          .map(
            (action) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.neutral100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(action.icon,
                        color: AppColors.neutral600, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          action.title,
                          style: AppTextStyles.labelMd.copyWith(
                            color: AppColors.neutral700,
                          ),
                        ),
                        Text(
                          action.subtitle,
                          style: AppTextStyles.bodyXs.copyWith(
                            color: AppColors.neutral600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.lock, size: 16, color: AppColors.neutral500),
                ],
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _OwnerDashboardBody extends ConsumerWidget {
  const _OwnerDashboardBody({
    required this.merchant,
    required this.hasMultipleMerchants,
    required this.ownerPending,
  });

  final OwnerMerchantSummary merchant;
  final bool hasMultipleMerchants;
  final bool ownerPending;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signalAsync = ref.watch(ownerOperationalSignalProvider(merchant.id));
    final signal = signalAsync.valueOrNull;
    final operationalSummary = resolveOperationalSummary(
      merchant: merchant,
      signal: signal,
    );
    final alerts = buildOwnerDashboardAlerts(
      merchant: merchant,
      ownerPending: ownerPending,
      signal: signal,
    );
    final isReviewPending = merchant.visibilityStatus == 'review_pending';
    final isNoVisible = merchant.visibilityStatus == 'hidden' ||
        merchant.visibilityStatus == 'suppressed';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
      children: [
        const Text('Eficiencia Operativa', style: AppTextStyles.headingMd),
        const SizedBox(height: 12),
        _OwnerMerchantHeader(merchant: merchant),
        if (!isReviewPending && !isNoVisible) ...[
          const SizedBox(height: 12),
          _OperationalSummaryCard(summary: operationalSummary),
        ],
        if (isReviewPending) ...[
          const SizedBox(height: 12),
          const _ReviewPendingCard(),
        ],
        if (isNoVisible) ...[
          const SizedBox(height: 12),
          _NoVisibleDashboardBlock(
            merchantId: merchant.id,
            alerts: alerts,
          ),
        ],
        if (hasMultipleMerchants) ...[
          const SizedBox(height: 12),
          const _InconsistencyBanner(),
        ],
        if (!isNoVisible && alerts.isNotEmpty) ...[
          const SizedBox(height: 14),
          _CriticalTasksCard(
            merchantId: merchant.id,
            alerts: alerts,
          ),
        ],
        if (!isReviewPending) ...[
          const SizedBox(height: 14),
          _MerchantStatusCard(merchant: merchant),
        ],
        const SizedBox(height: 14),
        if (isReviewPending)
          const _ReadOnlyQuickActions()
        else
          _OwnerQuickActions(
            merchant: merchant,
            onActionTap: (actionId) {
              unawaited(
                OwnerDashboardAnalytics.logQuickActionTapped(
                  merchantId: merchant.id,
                  actionId: actionId,
                ),
              );
            },
          ),
        if (!merchant.hasProducts && !isReviewPending) ...[
          const SizedBox(height: 14),
          const _EmptyProductsCard(),
        ],
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.center,
          child: TextButton.icon(
            onPressed: () =>
                context.push(AppRoutes.commerceDetailPath(merchant.id)),
            icon: const Icon(Icons.visibility_outlined),
            label: const Text('Ver cómo ven tu comercio'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary600,
              textStyle: AppTextStyles.labelMd,
            ),
          ),
        ),
      ],
    );
  }
}

class _OwnerMerchantHeader extends StatelessWidget {
  const _OwnerMerchantHeader({required this.merchant});

  final OwnerMerchantSummary merchant;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.neutral900.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.primary500,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.storefront, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(merchant.name, style: AppTextStyles.headingMd),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 14,
                      color: AppColors.neutral600,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        merchant.locationLabel,
                        style: AppTextStyles.bodySm,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _VisibilityPill(
            label: _visibilityLabel(merchant.visibilityStatus),
            status: merchant.visibilityStatus,
          ),
        ],
      ),
    );
  }

  String _visibilityLabel(String visibilityStatus) {
    switch (visibilityStatus) {
      case 'visible':
        return 'Visible';
      case 'review_pending':
        return 'En revisión';
      case 'suppressed':
        return 'Suprimido';
      default:
        return 'Oculto';
    }
  }
}

class _OperationalSummaryCard extends StatelessWidget {
  const _OperationalSummaryCard({required this.summary});

  final OwnerOperationalSummary summary;

  @override
  Widget build(BuildContext context) {
    final Color background = summary.isSpecialCondition
        ? AppColors.warningBg
        : summary.isUnknown
            ? AppColors.neutral100
            : AppColors.successBg;
    final Color foreground = summary.isSpecialCondition
        ? AppColors.tertiary700
        : summary.isUnknown
            ? AppColors.neutral700
            : AppColors.successFg;
    final IconData icon = summary.isSpecialCondition
        ? Icons.warning_amber_rounded
        : summary.isUnknown
            ? Icons.help_outline
            : Icons.check_circle_outline;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: foreground),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  summary.title,
                  style: AppTextStyles.labelMd.copyWith(color: foreground),
                ),
                const SizedBox(height: 4),
                Text(
                  summary.subtitle,
                  style: AppTextStyles.bodySm.copyWith(color: foreground),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewPendingCard extends StatelessWidget {
  const _ReviewPendingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.warningBg,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Text(
              'PENDIENTE',
              style:
                  AppTextStyles.labelSm.copyWith(color: AppColors.tertiary700),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Estamos revisando tu comercio',
            style: AppTextStyles.headingMd,
          ),
          const SizedBox(height: 8),
          Text(
            'Nuestro equipo de soporte está validando tus datos. Te avisamos apenas esté listo para empezar a vender.',
            style: AppTextStyles.bodySm.copyWith(color: AppColors.neutral700),
          ),
        ],
      ),
    );
  }
}

class _NoVisibleDashboardBlock extends StatelessWidget {
  const _NoVisibleDashboardBlock({
    required this.merchantId,
    required this.alerts,
  });

  final String merchantId;
  final List<OwnerDashboardAlert> alerts;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.warningBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.visibility_off_outlined,
                color: AppColors.tertiary700,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tu comercio no está visible en este momento',
                      style: AppTextStyles.labelMd,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tu negocio está pausado temporalmente del directorio público.',
                      style: AppTextStyles.bodySm.copyWith(
                        color: AppColors.neutral700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'TAREAS PRIORITARIAS',
          style: AppTextStyles.labelSm.copyWith(
            color: AppColors.neutral600,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 10),
        _CriticalTasksCard(
          merchantId: merchantId,
          alerts: alerts,
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.infoBg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tu concierge recomienda',
                style: AppTextStyles.labelSm.copyWith(
                  color: AppColors.primary700,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Actualizar tus fotos de catálogo mientras esperás la validación puede mejorar tu posicionamiento una vez reactivado.',
                style:
                    AppTextStyles.bodySm.copyWith(color: AppColors.primary700),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.center,
          child: TextButton.icon(
            onPressed: () => context.go(AppRoutes.profile),
            icon: const Icon(Icons.support_agent_outlined),
            label: const Text('Contactar soporte'),
          ),
        ),
      ],
    );
  }
}

class _CriticalTasksCard extends StatelessWidget {
  const _CriticalTasksCard({
    required this.merchantId,
    required this.alerts,
  });

  final String merchantId;
  final List<OwnerDashboardAlert> alerts;

  @override
  Widget build(BuildContext context) {
    final topAlerts = alerts.take(3).toList(growable: false);
    if (topAlerts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warningBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.assignment_late, color: AppColors.tertiary700),
              const SizedBox(width: 8),
              Text(
                'Lista de Tareas Cruciales',
                style:
                    AppTextStyles.labelMd.copyWith(color: AppColors.neutral900),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...topAlerts.map(
            (alert) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _CriticalTaskTile(
                merchantId: merchantId,
                alert: alert,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CriticalTaskTile extends StatelessWidget {
  const _CriticalTaskTile({
    required this.merchantId,
    required this.alert,
  });

  final String merchantId;
  final OwnerDashboardAlert alert;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_box_outline_blank,
              color: AppColors.neutral500),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(alert.title, style: AppTextStyles.labelMd),
                const SizedBox(height: 2),
                Text(
                  alert.message,
                  style: AppTextStyles.bodyXs
                      .copyWith(color: AppColors.neutral600),
                ),
                if (alert.ctaRoute != null && alert.ctaLabel != null) ...[
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: () {
                      unawaited(
                        OwnerDashboardAnalytics.logAlertTapped(
                          merchantId: merchantId,
                          alertId: alert.id,
                        ),
                      );
                      context.push(alert.ctaRoute!);
                    },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(alert.ctaLabel!),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VisibilityPill extends StatelessWidget {
  const _VisibilityPill({
    required this.label,
    required this.status,
  });

  final String label;
  final String status;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    switch (status) {
      case 'visible':
        bg = AppColors.successBg;
        fg = AppColors.successFg;
        break;
      case 'review_pending':
        bg = AppColors.infoBg;
        fg = AppColors.primary700;
        break;
      case 'suppressed':
        bg = AppColors.errorBg;
        fg = AppColors.errorFg;
        break;
      default:
        bg = AppColors.warningBg;
        fg = AppColors.tertiary700;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSm.copyWith(color: fg),
      ),
    );
  }
}

class _MerchantStatusCard extends StatelessWidget {
  const _MerchantStatusCard({required this.merchant});

  final OwnerMerchantSummary merchant;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _StatusRow(
            icon: Icons.storefront_outlined,
            title: 'Estado del comercio',
            badgeLabel: _statusLabel(merchant.status),
            badgeColor: _statusColor(merchant.status),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.neutral100),
          const SizedBox(height: 12),
          _StatusRow(
            icon: Icons.verified_outlined,
            title: 'Estado de confianza',
            badgeLabel: _verificationLabel(merchant.verificationStatus),
            badgeColor: AppColors.primary100,
            textColor: AppColors.primary700,
          ),
        ],
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'active':
        return 'Activo';
      case 'draft':
        return 'Borrador';
      case 'inactive':
        return 'Inactivo';
      case 'archived':
        return 'Archivado';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'active':
        return AppColors.successBg;
      case 'draft':
        return AppColors.warningBg;
      case 'archived':
        return AppColors.neutral200;
      default:
        return AppColors.neutral100;
    }
  }

  String _verificationLabel(String verificationStatus) {
    switch (verificationStatus) {
      case 'verified':
        return 'Comercio verificado';
      case 'validated':
        return 'Comercio validado';
      case 'claimed':
        return 'Comercio reclamado';
      case 'community_submitted':
        return 'Comunidad';
      default:
        return 'Sin verificar';
    }
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.icon,
    required this.title,
    required this.badgeLabel,
    required this.badgeColor,
    this.textColor = AppColors.neutral800,
  });

  final IconData icon;
  final String title;
  final String badgeLabel;
  final Color badgeColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.secondary500),
        const SizedBox(width: 10),
        Expanded(
          child: Text(title, style: AppTextStyles.labelMd),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: badgeColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            badgeLabel,
            style: AppTextStyles.labelSm.copyWith(color: textColor),
          ),
        ),
      ],
    );
  }
}

class _OwnerQuickActions extends StatelessWidget {
  const _OwnerQuickActions({
    required this.merchant,
    required this.onActionTap,
  });

  final OwnerMerchantSummary merchant;
  final void Function(String actionId) onActionTap;

  @override
  Widget build(BuildContext context) {
    final actions = <_OwnerAction>[
      const _OwnerAction(
        id: 'products',
        label: 'PRODUCTOS: Añadir novedad',
        subtitle: 'Carga nuevos ítems al catálogo.',
        icon: Icons.inventory_2_outlined,
        route: AppRoutes.ownerProducts,
      ),
      const _OwnerAction(
        id: 'schedules',
        label: 'HORARIOS: Ajustar apertura',
        subtitle: 'Modificá tu disponibilidad actual.',
        icon: Icons.schedule_outlined,
        route: AppRoutes.ownerSchedules,
      ),
      const _OwnerAction(
        id: 'signals',
        label: 'SEÑALES: Lanzar aviso',
        subtitle: 'Notificá novedades en tiempo real.',
        icon: Icons.campaign_outlined,
        route: AppRoutes.ownerSignals,
      ),
      const _OwnerAction(
        id: 'profile_status',
        label: 'PERFIL: Revisar datos',
        subtitle: 'Actualizá la ficha del comercio.',
        icon: Icons.fact_check_outlined,
        route: AppRoutes.ownerEdit,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ACCIONES RÁPIDAS',
          style: AppTextStyles.labelSm.copyWith(
            color: AppColors.neutral600,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.05,
          ),
          itemCount: actions.length,
          itemBuilder: (context, index) => _OwnerActionCard(
            action: actions[index],
            onActionTap: onActionTap,
          ),
        ),
        if (merchant.isPharmacy) ...[
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: () {
              onActionTap('pharmacy_duties');
              context.push(AppRoutes.ownerPharmacyDuties);
            },
            icon: const Icon(Icons.medical_services_outlined),
            label: const Text('Gestionar turnos de farmacia'),
          ),
        ],
      ],
    );
  }
}

class _OwnerActionCard extends StatelessWidget {
  const _OwnerActionCard({
    required this.action,
    required this.onActionTap,
  });

  final _OwnerAction action;
  final void Function(String actionId) onActionTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        onActionTap(action.id);
        context.push(action.route);
      },
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.primary50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(action.icon, color: AppColors.primary600),
            ),
            const Spacer(),
            Text(
              action.label,
              style: AppTextStyles.labelMd,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              action.subtitle,
              style: AppTextStyles.bodyXs,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _OwnerAction {
  const _OwnerAction({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.route,
  });

  final String id;
  final String label;
  final String subtitle;
  final IconData icon;
  final String route;
}

class _EmptyProductsCard extends StatelessWidget {
  const _EmptyProductsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: AppColors.neutral100,
              borderRadius: BorderRadius.circular(31),
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              color: AppColors.neutral700,
              size: 30,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Tu catálogo está vacío',
            style: AppTextStyles.headingSm,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Empezá cargando tu primer producto para que los vecinos te encuentren.',
            style: AppTextStyles.bodySm.copyWith(color: AppColors.neutral700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () => context.push(AppRoutes.ownerProducts),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary500,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(46),
            ),
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('Agregar producto'),
          ),
        ],
      ),
    );
  }
}

class _InconsistencyBanner extends StatelessWidget {
  const _InconsistencyBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warningBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'Detectamos más de un comercio asociado a tu usuario. Mostramos el más reciente.',
        style: AppTextStyles.bodySm.copyWith(color: AppColors.neutral800),
      ),
    );
  }
}

class _OwnerDashboardError extends StatelessWidget {
  const _OwnerDashboardError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'No pudimos cargar tu comercio.',
              style: AppTextStyles.headingSm,
            ),
            const SizedBox(height: 8),
            const Text(
              'Verificá tu conexión e intentá otra vez.',
              style: AppTextStyles.bodySm,
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary500,
                foregroundColor: Colors.white,
              ),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

bool _isAdminRole(String role) => role == 'admin' || role == 'super_admin';
