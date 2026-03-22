import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/placeholder_screen.dart';

/// AUTH-03 — Login placeholder.
/// Será reemplazada por la pantalla real en TuM2-0054.
class LoginPlaceholderScreen extends StatelessWidget {
  const LoginPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.infoBg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.primary200),
                ),
                child: Text(
                  'AUTH-03',
                  style: AppTextStyles.labelSm.copyWith(color: AppColors.primary600),
                ),
              ),
              const SizedBox(height: 16),
              Text('Login', style: AppTextStyles.headingMd),
              const SizedBox(height: 8),
              Text(
                'Pantalla en construcción — se implementa en TuM2-0054.',
                style: AppTextStyles.bodySm,
              ),

              const Spacer(),

              // Botones de prueba para desarrollo
              Text('Navegación de prueba', style: AppTextStyles.labelMd),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => context.go(AppRoutes.onboarding),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary500,
                  side: const BorderSide(color: AppColors.primary300),
                  minimumSize: const Size(double.infinity, 44),
                ),
                child: const Text('Ir a Onboarding (AUTH-02)'),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => context.go(AppRoutes.home),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary500,
                  minimumSize: const Size(double.infinity, 44),
                ),
                child: const Text('Simular login → HOME-01'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
