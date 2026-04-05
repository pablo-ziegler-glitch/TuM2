import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/auth_providers.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_text_input.dart';
import '../../../core/widgets/error_banner.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/secondary_button.dart';

/// AUTH-03 — Login / Registro
///
/// Pantalla de autenticación unificada: email magic link + Google Sign-In.
/// El sistema detecta si el email existe de forma transparente.
///
/// Estados:
///   1. Default (email vacío)
///   2. Email válido (botón activo, check en input)
///   3. Loading (spinner, inputs deshabilitados)
///   4. Error inline (email inválido)
///   5. Error banner de red (fuera del card, al final del scroll)
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  String? _emailError;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  bool get _emailIsValid {
    final email = _emailController.text.trim();
    return email.isNotEmpty && RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email);
  }

  String? _validateEmail(String value) {
    if (value.isEmpty) return null;
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(value)) {
      return 'Email inválido. Revisá el formato.';
    }
    return null;
  }

  Future<void> _sendMagicLink() async {
    final email = _emailController.text.trim();
    final error = _validateEmail(email);
    if (error != null) {
      setState(() => _emailError = error);
      return;
    }

    await ref.read(authOpProvider.notifier).sendMagicLink(email);

    if (!mounted) return;

    final state = ref.read(authOpProvider);
    if (state.emailSent) {
      context.go(
        '${AppRoutes.emailVerification}?email=${Uri.encodeComponent(email)}',
      );
    }
  }

  Future<void> _signInWithGoogle() async {
    await ref.read(authOpProvider.notifier).signInWithGoogle();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authOpProvider);
    final isLoading = authState.isLoading;
    final networkError = authState.errorMessage;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),

              // Logo TuM2 con ícono pin
              // TODO(assets): reemplazar con asset logo TuM2
              const Icon(
                Icons.location_on_rounded,
                size: 28,
                color: AppColors.primary500,
              ),
              const SizedBox(height: 4),
              Text(
                'TuM2',
                style: AppTextStyles.headingLg.copyWith(
                  color: AppColors.primary500,
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: 40),

              // Card de login
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Entrá a TuM2', style: AppTextStyles.headingMd),
                    const SizedBox(height: 4),
                    Text(
                      'Usá tu email o Google para continuar',
                      style: AppTextStyles.bodySm,
                    ),

                    const SizedBox(height: 24),

                    // Input email con check cuando es válido
                    AnimatedBuilder(
                      animation: _emailController,
                      builder: (context, _) {
                        return AppTextInput(
                          hint: 'Tu email',
                          controller: _emailController,
                          errorText: _emailError,
                          enabled: !isLoading,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.done,
                          autocorrect: false,
                          prefixIcon:
                              const Icon(Icons.mail_outline, size: 20),
                          suffixIcon: _emailIsValid
                              ? const Icon(
                                  Icons.check_circle_rounded,
                                  size: 20,
                                  color: AppColors.successFg,
                                )
                              : null,
                          onChanged: (_) {
                            if (_emailError != null) {
                              setState(() => _emailError = null);
                            }
                            setState(() {});
                          },
                          onSubmitted: (_) {
                            if (_emailIsValid) _sendMagicLink();
                          },
                        );
                      },
                    ),

                    const SizedBox(height: 16),

                    // Botón email
                    AnimatedBuilder(
                      animation: _emailController,
                      builder: (context, _) {
                        return PrimaryButton(
                          label: 'Continuar con email',
                          onPressed: _emailIsValid ? _sendMagicLink : null,
                          isLoading: isLoading,
                        );
                      },
                    ),

                    const SizedBox(height: 20),

                    // Separador
                    Row(
                      children: [
                        const Expanded(
                            child: Divider(color: AppColors.neutral200)),
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 12),
                          child: Text('o', style: AppTextStyles.bodyXs),
                        ),
                        const Expanded(
                            child: Divider(color: AppColors.neutral200)),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Botón Google (outline)
                    SecondaryButton(
                      label: 'Continuar con Google',
                      onPressed: isLoading ? null : _signInWithGoogle,
                      icon: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: AppColors.neutral100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Center(
                          // TODO(assets): reemplazar con asset logo Google
                          child: Text('G',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Error de red / servidor (fuera del card)
              if (networkError != null) ...[
                const SizedBox(height: 16),
                ErrorBanner(
                  message: networkError,
                  onDismiss: () =>
                      ref.read(authOpProvider.notifier).clearError(),
                ),
              ],

              const SizedBox(height: 24),

              // Términos y condiciones
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: AppTextStyles.bodyXs,
                  children: [
                    const TextSpan(text: 'Al continuar aceptás los '),
                    WidgetSpan(
                      child: GestureDetector(
                        onTap: () {/* TODO: abrir términos */},
                        child: Text(
                          'Términos y condiciones',
                          style: AppTextStyles.bodyXs.copyWith(
                            color: AppColors.primary500,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                    const TextSpan(text: ' y la '),
                    WidgetSpan(
                      child: GestureDetector(
                        onTap: () {/* TODO: abrir política */},
                        child: Text(
                          'Política de privacidad',
                          style: AppTextStyles.bodyXs.copyWith(
                            color: AppColors.primary500,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
