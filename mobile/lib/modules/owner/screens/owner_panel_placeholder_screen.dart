import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// OWNER-01 — Panel "Mi comercio" (modal full-screen).
///
/// Muestra el estado operativo actual, acciones rápidas, aviso de completitud
/// y banner promocional (datos mockeados — se conectará a Firestore en TuM2-0064).
class OwnerPanelPlaceholderScreen extends StatelessWidget {
  const OwnerPanelPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: CloseButton(
          color: AppColors.neutral900,
          onPressed: () => context.pop(),
        ),
        title: Text('Mi comercio', style: AppTextStyles.headingSm),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sección: Estado actual
            Text(
              'ESTADO ACTUAL',
              style: AppTextStyles.labelSm.copyWith(
                color: AppColors.neutral500,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.scaffoldBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.neutral100),
              ),
              child: Row(
                children: [
                  // Badge abierto
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.successBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Abierto',
                      style: AppTextStyles.labelSm.copyWith(
                        color: AppColors.successFg,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Cierra a las 20:00',
                      style: AppTextStyles.bodySm.copyWith(
                        color: AppColors.neutral600,
                      ),
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      side: BorderSide(color: AppColors.neutral300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Agregar señal',
                      style: AppTextStyles.labelSm.copyWith(
                        color: AppColors.neutral700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Sección: Acciones rápidas
            Text(
              'ACCIONES RÁPIDAS',
              style: AppTextStyles.labelSm.copyWith(
                color: AppColors.neutral500,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 10),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.6,
              children: [
                _ActionCard(
                  icon: Icons.edit_outlined,
                  label: 'Editar perfil',
                  onTap: () => context.push(AppRoutes.ownerEdit),
                ),
                _ActionCard(
                  icon: Icons.inventory_2_outlined,
                  label: 'Productos',
                  onTap: () => context.push(AppRoutes.ownerProducts),
                ),
                _ActionCard(
                  icon: Icons.schedule_outlined,
                  label: 'Horarios',
                  onTap: () => context.push(AppRoutes.ownerSchedules),
                ),
                _ActionCard(
                  icon: Icons.calendar_month_outlined,
                  label: 'Turnos',
                  onTap: () => context.push(AppRoutes.ownerDuties),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Aviso de completitud
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.warningBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFFBF49)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.warning_amber_outlined,
                        size: 18,
                        color: AppColors.warningFg,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Completá la descripción de tu comercio para aparecer mejor en búsquedas',
                          style: AppTextStyles.bodySm.copyWith(
                            color: AppColors.neutral800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => context.push(AppRoutes.ownerEdit),
                    child: Text(
                      'Completar →',
                      style: AppTextStyles.labelSm.copyWith(
                        color: AppColors.primary500,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Banner promocional
            Container(
              width: double.infinity,
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.neutral800,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          AppColors.neutral800,
                          AppColors.neutral700,
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'PROMOCIÓN DEL MES',
                          style: AppTextStyles.labelSm.copyWith(
                            color: AppColors.tertiary300,
                            letterSpacing: 1.2,
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'TENDA GOURMET',
                          style: AppTextStyles.headingMd.copyWith(
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Impulsá tus ventas hoy',
                          style: AppTextStyles.bodySm.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
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

// ── Widget de tarjeta de acción rápida ────────────────────────────────────────

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.scaffoldBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.neutral100),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24, color: AppColors.neutral700),
            const SizedBox(height: 6),
            Text(
              label,
              style: AppTextStyles.labelSm.copyWith(
                color: AppColors.neutral800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
