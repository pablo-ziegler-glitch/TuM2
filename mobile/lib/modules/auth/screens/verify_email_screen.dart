import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/auth_providers.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_text_input.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/primary_button.dart';
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
/// 5. Cross-device: campo de email para ingresar el email del otro dispositivo
class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({
    super.key,
    required this.email,
    this.isCrossDevice = false,
  });

  /// Email con el que se pidió el magic link. Vacío en caso cross-device.
  final String email;

  /// true cuando el link fue abierto en un dispositivo diferente al que
  /// lo solicitó (no hay pending_email_link en SharedPreferences).
  final bool isCrossDevice;

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  static const _cooldownSeconds = 30;
  int _secondsLeft = 0;
  Timer? _timer;

  /// Indica que el email fue enviado (primera vez o tras reenvío exitoso).
  bool _emailJustSent = true;

  // ── Cross-device ───────────────────────────────────────────────────────────
  final _crossDeviceEmailController = TextEditingController();
  bool _crossDeviceSubmitting = false;
  String? _crossDeviceError;

  bool get _crossDeviceEmailValid {
    final email = _crossDeviceEmailController.text.trim();
    return email.isNotEmpty && RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email);
  }

  bool get _canResend => _secondsLeft == 0;

  @override
  void initState() {
    super.initState();
    if (!widget.isCrossDevice) {
      // El email ya fue enviado en AUTH-03; arranca el cooldown de inmediato
      // para evitar reenvíos duplicados al abrir la pantalla.
      _startCooldown();
    }
    // En caso cross-device no hay email enviado, por lo que no mostramos
    // el banner de "enviado" ni el cooldown inicial.
    _emailJustSent = !widget.isCrossDevice;
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

    await ref.read(authOpProvider.notifier).sendMagicLink(widget.email);

    if (!mounted) return;

    final state = ref.read(authOpProvider);

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
      ref.read(authOpProvider.notifier).clearError();
    }
  }

  /// Procesa el magic link con el email ingresado manualmente (caso cross-device).
  Future<void> _processCrossDeviceLink() async {
    final email = _crossDeviceEmailController.text.trim();
    if (email.isEmpty) return;

    final link = ref.read(pendingMagicLinkProvider);
    if (link == null) {
      setState(() {
        _crossDeviceError =
            'No se encontró el link. Probá abrirlo directamente desde el email.';
      });
      return;
    }

    setState(() {
      _crossDeviceSubmitting = true;
      _crossDeviceError = null;
    });

    await ref
        .read(authOpProvider.notifier)
        .handleEmailLink(link, emailOverride: email);

    if (!mounted) return;

    final state = ref.read(authOpProvider);
    if (state.errorMessage != null) {
      setState(() {
        _crossDeviceSubmitting = false;
        _crossDeviceError = state.errorMessage;
      });
      ref.read(authOpProvider.notifier).clearError();
    }
    // Si el auth fue exitoso, el router redirige automáticamente via authStateChanges.
  }

  @override
  void dispose() {
    _timer?.cancel();
    _crossDeviceEmailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isCrossDevice) {
      return _buildCrossDeviceScreen();
    }

    final emailDisplay = widget.email.isNotEmpty ? widget.email : 'tu email';
    final isLoading = ref.watch(authOpProvider).isLoading;

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

              const Text(
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
                disabledLabel:
                    _secondsLeft > 0 ? 'Reenviar en ${_secondsLeft}s' : null,
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
                      valueColor:
                          const AlwaysStoppedAnimation(AppColors.primary500),
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

  /// Pantalla alternativa para el caso cross-device:
  /// el usuario abrió el link en un dispositivo distinto al que lo pidió.
  Widget _buildCrossDeviceScreen() {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ícono ilustrativo
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: AppColors.primary50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.devices_outlined,
                  size: 32,
                  color: AppColors.primary400,
                ),
              ),

              const SizedBox(height: 24),

              const Text(
                '¿Abriste el link en otro dispositivo?',
                style: AppTextStyles.headingMd,
              ),

              const SizedBox(height: 12),

              Text(
                'Ingresá el email con el que pediste el link para completar el ingreso.',
                style: AppTextStyles.bodyMd.copyWith(
                  color: AppColors.neutral700,
                ),
              ),

              const SizedBox(height: 32),

              AnimatedBuilder(
                animation: _crossDeviceEmailController,
                builder: (context, _) {
                  return AppTextInput(
                    hint: 'Ingresá el email con el que pediste el link',
                    controller: _crossDeviceEmailController,
                    errorText: _crossDeviceError,
                    enabled: !_crossDeviceSubmitting,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    prefixIcon: const Icon(Icons.mail_outline, size: 20),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) {
                      if (_crossDeviceEmailValid) _processCrossDeviceLink();
                    },
                    onChanged: (_) {
                      if (_crossDeviceError != null) {
                        setState(() => _crossDeviceError = null);
                      }
                    },
                  );
                },
              ),

              const SizedBox(height: 20),

              AnimatedBuilder(
                animation: _crossDeviceEmailController,
                builder: (context, _) {
                  return PrimaryButton(
                    label: 'Ingresar',
                    onPressed: _crossDeviceEmailValid && !_crossDeviceSubmitting
                        ? _processCrossDeviceLink
                        : null,
                    isLoading: _crossDeviceSubmitting,
                  );
                },
              ),

              const SizedBox(height: 16),

              Center(
                child: TextButton(
                  onPressed: () => context.go(AppRoutes.login),
                  child: Text(
                    'Volver al inicio',
                    style: AppTextStyles.labelSm.copyWith(
                      color: AppColors.primary500,
                      decoration: TextDecoration.underline,
                    ),
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

// ── Widgets auxiliares ────────────────────────────────────────────────────────

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
          color: AppColors.successFg.withValues(alpha: 0.4),
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
