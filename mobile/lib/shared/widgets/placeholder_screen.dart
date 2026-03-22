import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// Pantalla de placeholder genérica para rutas aún no implementadas.
/// Solo se usa en dev/QA — no aparece en producción.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({
    super.key,
    required this.screenId,
    required this.label,
  });

  final String screenId;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                screenId,
                style: AppTextStyles.labelSm.copyWith(
                  color: AppColors.neutral500,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 8),
              Icon(Icons.construction_outlined,
                  size: 48, color: AppColors.neutral400),
              const SizedBox(height: 12),
              Text(label, style: AppTextStyles.headingSm),
              const SizedBox(height: 4),
              Text(
                'Pantalla en construcción',
                style: AppTextStyles.bodySm,
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () => context.pop(),
                child: Text(
                  'Volver',
                  style: AppTextStyles.labelMd
                      .copyWith(color: AppColors.primary500),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Componente temporal — solo dev y QA — no aparece en producción',
                style: AppTextStyles.bodyXs.copyWith(color: AppColors.neutral400),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
