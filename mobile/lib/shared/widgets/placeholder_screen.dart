import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// Acción de navegación de prueba para [PlaceholderScreen].
class NavAction {
  final String label;
  final VoidCallback onTap;

  const NavAction({required this.label, required this.onTap});
}

/// Pantalla placeholder tipificada para uso durante el desarrollo.
///
/// Muestra el ID de pantalla, el label descriptivo y botones de navegación
/// de prueba opcionales. Todas las instancias son descartables — serán
/// reemplazadas por las pantallas reales en tarjetas posteriores.
class PlaceholderScreen extends StatelessWidget {
  final String screenId;
  final String label;
  final String? roleRequired;
  final List<NavAction> navActions;

  const PlaceholderScreen({
    super.key,
    required this.screenId,
    required this.label,
    this.roleRequired,
    this.navActions = const [],
  });

  String _roleLabel(String role) {
    switch (role) {
      case 'admin':
        return 'administración';
      case 'owner':
        return 'comercio';
      case 'customer':
        return 'cliente';
      case 'super_admin':
        return 'superadministración';
      default:
        return role;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text(screenId, style: AppTextStyles.labelMd),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Badge de identificación
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.infoBg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.primary200),
                ),
                child: Text(
                  screenId,
                  style: AppTextStyles.labelSm
                      .copyWith(color: AppColors.primary600),
                ),
              ),
              const SizedBox(height: 16),

              // Label principal
              Text(label, style: AppTextStyles.headingMd),
              const SizedBox(height: 8),

              // Indicador de rol requerido
              if (roleRequired != null) ...[
                Text(
                  'Rol requerido: ${_roleLabel(roleRequired!)}',
                  style: AppTextStyles.bodySm
                      .copyWith(color: AppColors.neutral500),
                ),
                const SizedBox(height: 8),
              ],

              // Indicador "en construcción"
              const Text(
                'Pantalla en construcción — se implementa en tarjeta posterior.',
                style: AppTextStyles.bodySm,
              ),

              // Botones de navegación de prueba
              if (navActions.isNotEmpty) ...[
                const SizedBox(height: 32),
                const Text('Navegación de prueba', style: AppTextStyles.labelMd),
                const SizedBox(height: 12),
                ...navActions.map(
                  (action) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: OutlinedButton(
                      onPressed: action.onTap,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary500,
                        side: const BorderSide(color: AppColors.primary300),
                        minimumSize: const Size(double.infinity, 44),
                      ),
                      child: Text(action.label),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
