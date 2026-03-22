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
/// Estados:
/// 1. Default (esperando que el user abra el link) — banner verde "Email enviado correctamente"
/// 2. Cooldown activo (botón deshabilitado + countdown + barra de progreso)
/// 3. Link reenviado (toast verde "¡Link reenviado! Revisá tu bandeja.")
/// 4. Error reenvío (toast rojo con mensaje)
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

  /// Indica que el email fue enviado (primera vez o tras reenvío exitoso).
  /// Controla el banner verde y la ilustración con check.
  bool _emailJustSent = true;

  bool get _canResend => _secondsLeft == 0;

  @override
  void initState() {
    super.initState();
    // El email ya fue enviado en AUTH-03; arranca el cooldown de inmediato
    // para evitar reenvíos duplicados al abrir la pantalla.
    _startCooldown();
  }

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
      setState(() => _emailJustSent = true);
      AppToast.show(
        context,
        message: '¡Link reenviado! Revisá tu bandeja.',
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
              // Ilustración — sobre con check badge cuando se envió
              _EnvelopeIllustration(sent: _emailJustSent),

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
                    const TextSpan(text: ' Tocalo para ingresar a TuM2.'),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Banner "Email enviado correctamente"
              if (_emailJustSent) _SuccessBanner(),

              const SizedBox(height: 20),

              // Botón reenviar con cooldown
              SecondaryButton(
                label: 'Reenviar link',
                disabledLabel: _secondsLeft > 0
                    ? 'Reenviar en ${_secondsLeft}s'
                    : null,
                onPressed: _canResend && !isLoading ? _resend : null,
                isLoading: isLoading,
              ),

              // Barra de progreso del cooldown
              if (_secondsLeft > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: _secondsLeft / _cooldownSeconds,
                      backgroundColor: AppColors.neutral100,
                      valueColor: const AlwaysStoppedAnimation(AppColors.primary500),
                      minHeight: 2,
                    ),
                  ),
                ),

              const SizedBox(height: 20),

              // Usar otro email
              TextButton(
                onPressed: () => context.go(AppRoutes.login),
                child: Text(
                  'Usar otro email',
                  style: AppTextStyles.labelSm.copyWith(
                    color: AppColors.primary500,
                    decoration: TextDecoration.underline,
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

/// Ilustración del sobre. Muestra check badge cuando [sent] es true.
class _EnvelopeIllustration extends StatelessWidget {
  const _EnvelopeIllustration({required this.sent});

  final bool sent;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: const BoxDecoration(
            color: AppColors.primary50,
            shape: BoxShape.circle,
          ),
          child: Icon(
            sent
                ? Icons.mark_email_read_outlined
                : Icons.mark_email_unread_outlined,
            size: 48,
            color: AppColors.primary400,
          ),
        ),
        if (sent)
          Positioned(
            top: -4,
            right: -4,
            child: Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                color: AppColors.successFg,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                size: 16,
                color: Colors.white,
              ),
            ),
          ),
      ],
    );
  }
}

/// Banner verde inline "Email enviado correctamente".
class _SuccessBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.successBg,
        border: Border.all(
          color: AppColors.successFg.withOpacity(0.4),
          width: 0.8,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_outline_rounded,
            size: 16,
            color: AppColors.successFg,
          ),
          const SizedBox(width: 8),
          Text(
            'Email enviado correctamente',
            style: AppTextStyles.labelSm.copyWith(
              color: AppColors.successFg,
            ),
          ),
        ],
      ),
    );
  }
}
