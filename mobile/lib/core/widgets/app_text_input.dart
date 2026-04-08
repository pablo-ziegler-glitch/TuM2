import 'package:flutter/material.dart';

/// Campo de texto estándar de TuM2.
///
/// Toma estilos del [InputDecorationTheme] global para mantener consistencia.
class AppTextInput extends StatelessWidget {
  const AppTextInput({
    super.key,
    required this.hint,
    this.controller,
    this.errorText,
    this.enabled = true,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.prefixIcon,
    this.suffixIcon,
    this.autofocus = false,
    this.autocorrect = false,
  });

  final String hint;
  final TextEditingController? controller;
  final String? errorText;
  final bool enabled;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool autofocus;
  final bool autocorrect;

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null && errorText!.isNotEmpty;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: controller,
          enabled: enabled,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          autofocus: autofocus,
          autocorrect: autocorrect,
          style: theme.textTheme.bodyLarge,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: prefixIcon,
            suffixIcon: suffixIcon,
            prefixIconColor: hasError
                ? colors.error
                : enabled
                    ? colors.onSurfaceVariant
                    : colors.outline,
            errorText: hasError ? errorText : null,
          ),
        ),
      ],
    );
  }
}
