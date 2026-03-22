import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Campo de texto estándar de TuM2.
///
/// Borde neutral200, radius 10, soporte para estado de error y disabled.
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
          style: AppTextStyles.bodyMd,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTextStyles.bodyMd.copyWith(
              color: AppColors.neutral400,
            ),
            prefixIcon: prefixIcon,
            suffixIcon: suffixIcon,
            prefixIconColor: hasError
                ? AppColors.errorFg
                : enabled
                    ? AppColors.neutral600
                    : AppColors.neutral400,
            filled: true,
            fillColor: enabled ? AppColors.surface : AppColors.neutral50,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: _border(AppColors.neutral200),
            enabledBorder: _border(
              hasError ? AppColors.errorFg : AppColors.neutral200,
            ),
            focusedBorder: _border(
              hasError ? AppColors.errorFg : AppColors.primary500,
              width: 1.5,
            ),
            disabledBorder: _border(AppColors.neutral100),
            errorBorder: _border(AppColors.errorFg),
            focusedErrorBorder: _border(AppColors.errorFg, width: 1.5),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.error_outline,
                  size: 14, color: AppColors.errorFg),
              const SizedBox(width: 4),
              Text(
                errorText!,
                style: AppTextStyles.bodyXs.copyWith(
                  color: AppColors.errorFg,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  OutlineInputBorder _border(Color color, {double width = 1.0}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}
