import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_notifier.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
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
  bool _redirectedToOnboarding = false;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider).authState;
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

    final ownerMerchantAsync = ref.watch(ownerMerchantProvider);

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
      body: ownerMerchantAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary500),
        ),
        error: (_, __) => _OwnerDashboardError(
          onRetry: () => ref.invalidate(ownerMerchantProvider),
        ),
        data: (resolution) {
          if (!resolution.hasMerchant) {
            _redirectToOnboarding(context);
            return const Center(child: CircularProgressIndicator());
          }

          return _OwnerDashboardBody(
            merchant: resolution.primaryMerchant!,
            hasMultipleMerchants: resolution.hasMultipleMerchants,
          );
        },
      ),
    );
  }

  void _redirectToOnboarding(BuildContext context) {
    if (_redirectedToOnboarding) return;
    _redirectedToOnboarding = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.go(AppRoutes.onboardingOwner);
    });
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
          route: AppRoutes.ownerDuties,
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

class _OwnerDashboardBody extends StatelessWidget {
  const _OwnerDashboardBody({
    required this.merchant,
    required this.hasMultipleMerchants,
  });

  final OwnerMerchantSummary merchant;
  final bool hasMultipleMerchants;

  @override
  Widget build(BuildContext context) {
    final showScheduleAlert =
        merchant.status == 'active' && !merchant.hasSchedules;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        _OwnerMerchantHeader(merchant: merchant),
        if (hasMultipleMerchants) ...[
          const SizedBox(height: 12),
          const _InconsistencyBanner(),
        ],
        if (merchant.isReviewPending) ...[
          const SizedBox(height: 14),
          const _ReviewPendingCard(),
        ],
        if (showScheduleAlert) ...[
          const SizedBox(height: 14),
          const _ScheduleAlertCard(),
        ],
        const SizedBox(height: 14),
        _MerchantStatusCard(merchant: merchant),
        const SizedBox(height: 14),
        _OwnerQuickActions(merchant: merchant),
        if (!merchant.hasProducts) ...[
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
          _VisibilityPill(label: _visibilityLabel(merchant.visibilityStatus)),
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

class _VisibilityPill extends StatelessWidget {
  const _VisibilityPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.successBg,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSm.copyWith(color: AppColors.successFg),
      ),
    );
  }
}

class _ReviewPendingCard extends StatelessWidget {
  const _ReviewPendingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary600, AppColors.primary500],
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Estamos revisando tu perfil',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Nuestro equipo está validando la información del comercio.',
            style: TextStyle(color: Color(0xFFDCE7FF)),
          ),
        ],
      ),
    );
  }
}

class _ScheduleAlertCard extends StatelessWidget {
  const _ScheduleAlertCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.tertiary50,
        borderRadius: BorderRadius.circular(16),
        border: const Border(
          left: BorderSide(color: AppColors.tertiary500, width: 4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Horario no configurado',
            style: AppTextStyles.labelSm.copyWith(color: AppColors.tertiary700),
          ),
          const SizedBox(height: 6),
          Text(
            'Agregá tus horarios para aparecer como abierto.',
            style: AppTextStyles.bodySm.copyWith(color: AppColors.tertiary800),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => context.push(AppRoutes.ownerSchedules),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.tertiary500,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.schedule, size: 18),
            label: const Text('Configurar ahora'),
          ),
        ],
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
  const _OwnerQuickActions({required this.merchant});

  final OwnerMerchantSummary merchant;

  @override
  Widget build(BuildContext context) {
    final actions = <_OwnerAction>[
      const _OwnerAction(
        label: 'Gestionar productos',
        subtitle: 'Stock y precios',
        icon: Icons.inventory_2_outlined,
        route: AppRoutes.ownerProducts,
      ),
      const _OwnerAction(
        label: 'Editar horarios',
        subtitle: 'Atención y apertura',
        icon: Icons.schedule_outlined,
        route: AppRoutes.ownerSchedules,
      ),
      const _OwnerAction(
        label: 'Señales operativas',
        subtitle: 'Estados del comercio',
        icon: Icons.campaign_outlined,
        route: AppRoutes.ownerSignals,
      ),
    ];

    if (merchant.isPharmacy) {
      actions.add(
        const _OwnerAction(
          label: 'Turnos de farmacia',
          subtitle: 'Guardias y calendario',
          icon: Icons.medical_services_outlined,
          route: AppRoutes.ownerDuties,
        ),
      );
    }

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
          itemBuilder: (context, index) =>
              _OwnerActionCard(action: actions[index]),
        ),
      ],
    );
  }
}

class _OwnerActionCard extends StatelessWidget {
  const _OwnerActionCard({required this.action});

  final _OwnerAction action;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push(action.route),
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
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.route,
  });

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
