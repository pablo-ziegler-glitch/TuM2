import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Botón secundario (outline) de TuM2.
///
/// Full-width, altura 52px, borde primary500, fondo blanco.
/// Se deshabilita cuando [onPressed] es null o [isLoading] es true.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.disabledLabel,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Widget? icon;

  /// Label alternativo cuando el botón está deshabilitado (p.ej. "Reenviar en 28s").
  final String? disabledLabel;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isLoading;
    final displayLabel =
        (!enabled && disabledLabel != null) ? disabledLabel! : label;

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: enabled ? onPressed : null,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary500,
          disabledForegroundColor: AppColors.neutral500,
          backgroundColor: AppColors.surface,
          side: BorderSide(
            color: enabled ? AppColors.primary500 : AppColors.neutral300,
            width: 1.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor:
                      AlwaysStoppedAnimation(AppColors.primary500),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    icon!,
                    const SizedBox(width: 10),
                  ],
                  Text(
                    displayLabel,
                    style: AppTextStyles.labelMd.copyWith(
                      color: enabled
                          ? AppColors.primary500
                          : AppColors.neutral500,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
