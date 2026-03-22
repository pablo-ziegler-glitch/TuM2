import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/auth_providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/secondary_button.dart';

/// AUTH-04 — Verificación de email (magic link)
///
/// El usuario ve esta pantalla después de ingresar su email en AUTH-03.
/// Debe tocar el link en su email para completar el login.
///
/// Funcionalidades:
/// - Botón "Reenviar link" con cooldown de 30 segundos
/// - Link "Usar otro email" → vuelve a AUTH-03
/// - Toast de confirmación al reenviar
///
/// Estados:
/// 1. Default (esperando que el user abra el link)
/// 2. Cooldown activo (botón deshabilitado + countdown)
/// 3. Link reenviado (toast verde)
/// 4. Error reenvío (toast rojo)
///
/// TODO(figma): implementar ilustración "sobre abierto" cuando lleguen los mockups.
class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key, required this.email});

  final String email;

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  static const _cooldownSeconds = 30;
  int _secondsLeft = 0;
  Timer? _timer;

  bool get _canResend => _secondsLeft == 0;

  void _startCooldown() {
    setState(() => _secondsLeft = _cooldownSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft <= 1) {
        t.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  Future<void> _resend() async {
    if (!_canResend) return;

    await ref
        .read(authNotifierProvider.notifier)
        .sendMagicLink(widget.email);

    if (!mounted) return;

    final state = ref.read(authNotifierProvider);

    if (state.emailSent) {
      _startCooldown();
      AppToast.show(
        context,
        message: 'Link reenviado',
        type: ToastType.success,
      );
    } else if (state.errorMessage != null) {
      AppToast.show(
        context,
        message: state.errorMessage!,
        type: ToastType.error,
      );
      ref.read(authNotifierProvider.notifier).clearError();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final emailDisplay = widget.email.isNotEmpty ? widget.email : 'tu email';
    final isLoading = ref.watch(authNotifierProvider).isLoading;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // TODO(figma): ilustración "sobre abierto con check"
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.primary50,
                  borderRadius: BorderRadius.circular(50),
                ),
                child: const Icon(
                  Icons.mark_email_unread_outlined,
                  size: 48,
                  color: AppColors.primary400,
                ),
              ),

              const SizedBox(height: 32),

              Text(
                'Revisá tu email',
                style: AppTextStyles.headingMd,
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 12),

              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: AppTextStyles.bodyMd.copyWith(
                    color: AppColors.neutral700,
                  ),
                  children: [
                    const TextSpan(text: 'Te mandamos un link a '),
                    TextSpan(
                      text: emailDisplay,
                      style: AppTextStyles.bodyMd.copyWith(
                        color: AppColors.primary500,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const TextSpan(
                      text: '\nTocalo para ingresar a TuM2.',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // Botón reenviar con cooldown
              SecondaryButton(
                label: 'Reenviar link',
                disabledLabel: _secondsLeft > 0
                    ? 'Reenviar en ${_secondsLeft}s'
                    : null,
                onPressed: _canResend && !isLoading ? _resend : null,
                isLoading: isLoading,
              ),

              const SizedBox(height: 20),

              // Usar otro email
              TextButton(
                onPressed: () => context.go(AppRoutes.login),
                child: Text(
                  'Usar otro email',
                  style: AppTextStyles.labelSm.copyWith(
                    color: AppColors.primary500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
