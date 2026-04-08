import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Botón primario de TuM2.
///
/// Full-width, altura 52px, fondo primary500.
/// Muestra spinner cuando [isLoading] es true.
/// Se deshabilita cuando [onPressed] es null o [isLoading] es true.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.backgroundColor,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  /// Ícono opcional a la izquierda del label (p.ej. logo Google).
  final Widget? icon;

  /// Color de fondo alternativo (p.ej. secondary500 o tertiary500 en onboarding).
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isLoading;
    final theme = Theme.of(context);
    final baseStyle = theme.elevatedButtonTheme.style;
    final style = backgroundColor == null
        ? baseStyle
        : baseStyle?.copyWith(
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.disabled)) {
                return AppColors.disabled;
              }
              if (states.contains(WidgetState.pressed)) {
                return Color.alphaBlend(
                  const Color(0x26000000),
                  backgroundColor!,
                );
              }
              return backgroundColor!;
            }),
          );

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: style,
        child: isLoading
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor:
                      AlwaysStoppedAnimation(theme.colorScheme.onPrimary),
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
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
      ),
    );
  }
}
