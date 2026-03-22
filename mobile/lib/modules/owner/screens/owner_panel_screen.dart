import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// OWNER-01 — Panel principal del dueño (modal full-screen).
/// Accesible desde el tab Perfil con rol owner.
class OwnerPanelScreen extends StatelessWidget {
  const OwnerPanelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          color: AppColors.neutral900,
          onPressed: () => context.pop(),
        ),
        title: Text('Mi comercio', style: AppTextStyles.headingSm),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _StatusSection(),
          const SizedBox(height: 20),
          _QuickActions(),
          const SizedBox(height: 16),
          _WarningBanner(),
          const SizedBox(height: 12),
          _PromoBanner(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ── Estado actual ─────────────────────────────────────────────────────────────

class _StatusSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ESTADO ACTUAL',
            style: AppTextStyles.labelSm.copyWith(
              color: AppColors.neutral500,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.successBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Abierto',
                  style: AppTextStyles.labelMd
                      .copyWith(color: AppColors.successFg),
                ),
              ),
              const SizedBox(width: 10),
              Text('Cierra a las 22:00', style: AppTextStyles.bodySm),
              const Spacer(),
              GestureDetector(
                onTap: () {},
                child: Text(
                  'Agregar seña →',
                  style: AppTextStyles.labelSm
                      .copyWith(color: AppColors.primary500),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Acciones rápidas ──────────────────────────────────────────────────────────

class _QuickActions extends StatelessWidget {
  static const _actions = [
    (icon: Icons.person_outline, label: 'Editar perfil', route: AppRoutes.ownerEdit),
    (icon: Icons.inventory_2_outlined, label: 'Productos', route: AppRoutes.ownerProducts),
    (icon: Icons.schedule_outlined, label: 'Horarios', route: AppRoutes.ownerSchedules),
    (icon: Icons.calendar_today_outlined, label: 'Turnos', route: AppRoutes.ownerDuties),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ACCIONES RÁPIDAS',
          style: AppTextStyles.labelSm.copyWith(
            color: AppColors.neutral500,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 2.3,
          children:
              _actions.map((a) => _ActionTile(icon: a.icon, label: a.label, route: a.route)).toList(),
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.icon, required this.label, required this.route});
  final IconData icon;
  final String label;
  final String route;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push(route),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const SizedBox(width: 12),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: AppColors.primary500, size: 20),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                label,
                style: AppTextStyles.labelMd,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Banner de advertencia ─────────────────────────────────────────────────────

class _WarningBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warningBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.tertiary200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded,
              color: AppColors.warningFg, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Completá la descripción de tu comercio para aparecer mejor en búsquedas',
                  style: AppTextStyles.bodySm
                      .copyWith(color: AppColors.neutral800),
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () => context.push(AppRoutes.ownerEdit),
                  child: Text(
                    'Completar →',
                    style: AppTextStyles.labelSm
                        .copyWith(color: AppColors.primary500),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Banner promocional ────────────────────────────────────────────────────────

class _PromoBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: AppColors.neutral900,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TENDA',
                  style: AppTextStyles.headingSm.copyWith(
                    color: AppColors.surface,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                Text(
                  'Pastelería / Gourmet',
                  style:
                      AppTextStyles.bodyXs.copyWith(color: AppColors.neutral400),
                ),
                const SizedBox(height: 4),
                Text(
                  'Impulsá tus ventas hoy',
                  style: AppTextStyles.labelMd
                      .copyWith(color: AppColors.surface),
                ),
              ],
            ),
          ),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.neutral700,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.storefront,
                color: AppColors.neutral500, size: 28),
          ),
        ],
      ),
    );
  }
}
