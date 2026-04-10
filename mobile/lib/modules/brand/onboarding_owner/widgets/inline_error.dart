import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';

/// Mensaje de error inline debajo de un campo.
/// Patrón de validación triple (ver ONBOARDING-OWNER-EXCEPTIONS.md §Grupo C).
class InlineError extends StatelessWidget {
  final String message;
  final bool isWarning;

  const InlineError({super.key, required this.message, this.isWarning = false});

  @override
  Widget build(BuildContext context) {
    final color = isWarning ? AppColors.warningFg : AppColors.errorFg;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('△ ', style: AppTextStyles.bodyXs.copyWith(color: color)),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.bodyXs.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// Banner global de error / warning al tope de la pantalla.
/// Primera capa del patrón de validación triple.
class ValidationBanner extends StatelessWidget {
  final String title;
  final String body;
  final bool isWarning;

  const ValidationBanner({
    super.key,
    required this.title,
    required this.body,
    this.isWarning = false,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isWarning ? AppColors.warningBg : AppColors.errorBg;
    final fgColor = isWarning ? AppColors.warningFg : AppColors.errorFg;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: fgColor.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: fgColor, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.labelSm.copyWith(
                    color: fgColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(body,
                    style: AppTextStyles.bodyXs.copyWith(color: fgColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
