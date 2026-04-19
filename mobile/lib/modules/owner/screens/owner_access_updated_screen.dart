import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_notifier.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

enum OwnerAccessUpdatedTarget { owner, customer }

enum OwnerAccessUpdatedReason {
  approvedTransition,
  claimClosed,
  deepRouteAccessChanged,
}

class OwnerAccessUpdatedScreen extends ConsumerStatefulWidget {
  const OwnerAccessUpdatedScreen({
    super.key,
    required this.target,
    required this.reason,
    this.fromPath,
  });

  final OwnerAccessUpdatedTarget target;
  final OwnerAccessUpdatedReason reason;
  final String? fromPath;

  @override
  ConsumerState<OwnerAccessUpdatedScreen> createState() =>
      _OwnerAccessUpdatedScreenState();
}

class _OwnerAccessUpdatedScreenState
    extends ConsumerState<OwnerAccessUpdatedScreen> {
  Timer? _redirectTimer;
  bool _navigated = false;
  bool _syncingOwner = false;

  @override
  void initState() {
    super.initState();
    if (widget.target == OwnerAccessUpdatedTarget.owner &&
        widget.reason == OwnerAccessUpdatedReason.approvedTransition) {
      _startOwnerApprovedFlow();
      return;
    }

    _redirectTimer = Timer(const Duration(seconds: 4), _continueFlow);
  }

  @override
  void dispose() {
    _redirectTimer?.cancel();
    super.dispose();
  }

  Future<void> _startOwnerApprovedFlow() async {
    setState(() {
      _syncingOwner = true;
    });
    await ref.read(authNotifierProvider).refreshSession();
    if (!mounted) return;
    setState(() {
      _syncingOwner = false;
    });
    _redirectTimer = Timer(const Duration(seconds: 3), _continueFlow);
  }

  void _continueFlow() {
    if (_navigated || !mounted) return;
    _navigated = true;

    if (widget.target == OwnerAccessUpdatedTarget.owner) {
      context.go(AppRoutes.ownerResolve);
      return;
    }
    context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider).authState;
    final isOwner = authState is AuthAuthenticated && authState.role == 'owner';

    if (widget.target == OwnerAccessUpdatedTarget.owner &&
        widget.reason == OwnerAccessUpdatedReason.approvedTransition &&
        isOwner &&
        !_syncingOwner) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _continueFlow());
    }

    final content = _resolveContent();

    return Scaffold(
      backgroundColor: AppColors.neutral50,
      appBar: AppBar(
        backgroundColor: AppColors.neutral50,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Mi comercio', style: AppTextStyles.headingSm),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    content.icon,
                    color: content.iconColor,
                    size: 36,
                  ),
                  const SizedBox(height: 14),
                  Text(content.title, style: AppTextStyles.headingSm),
                  const SizedBox(height: 8),
                  Text(content.description, style: AppTextStyles.bodySm),
                  if (widget.fromPath != null &&
                      widget.fromPath!.isNotEmpty &&
                      widget.reason ==
                          OwnerAccessUpdatedReason.deepRouteAccessChanged) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Ruta previa: ${widget.fromPath}',
                      style: AppTextStyles.bodyXs.copyWith(
                        color: AppColors.neutral600,
                      ),
                    ),
                  ],
                  if (_syncingOwner) ...[
                    const SizedBox(height: 14),
                    const LinearProgressIndicator(
                      color: AppColors.primary500,
                      backgroundColor: AppColors.neutral200,
                    ),
                  ],
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _continueFlow,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary500,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: Text(content.primaryCta),
                  ),
                  if (content.secondaryCta != null) ...[
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: () => context.go(AppRoutes.claimIntro),
                      child: Text(content.secondaryCta!),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  _OwnerAccessUpdatedCopy _resolveContent() {
    if (widget.target == OwnerAccessUpdatedTarget.owner &&
        widget.reason == OwnerAccessUpdatedReason.approvedTransition) {
      return const _OwnerAccessUpdatedCopy(
        title: '¡Todo listo! Ya sos Owner en TuM2.',
        description: 'Estamos preparando tu panel.',
        primaryCta: 'Ir a Mi comercio',
        icon: Icons.check_circle,
        iconColor: AppColors.successFg,
      );
    }

    if (widget.target == OwnerAccessUpdatedTarget.customer &&
        widget.reason == OwnerAccessUpdatedReason.claimClosed) {
      return const _OwnerAccessUpdatedCopy(
        title: 'No pudimos validar tu solicitud de Owner',
        description:
            'Por ahora no pudimos darte de alta como Owner. Revisá tu información e intentá de nuevo cuando quieras.',
        primaryCta: 'Volver a Inicio',
        secondaryCta: 'Ver requisitos de registro',
        icon: Icons.info_outline,
        iconColor: AppColors.primary600,
      );
    }

    if (widget.target == OwnerAccessUpdatedTarget.customer) {
      return const _OwnerAccessUpdatedCopy(
        title: 'Actualizamos tu perfil',
        description:
            'Para que todo funcione bien, necesitamos llevarte al inicio de tu experiencia como cliente.',
        primaryCta: 'Entendido',
        icon: Icons.sync_problem,
        iconColor: AppColors.warningFg,
      );
    }

    return const _OwnerAccessUpdatedCopy(
      title: 'Actualizamos tu acceso',
      description:
          'Ahora tenés permisos de Owner. Continuá para entrar a Mi comercio.',
      primaryCta: 'Continuar a mi panel',
      icon: Icons.verified_user,
      iconColor: AppColors.primary600,
    );
  }
}

class _OwnerAccessUpdatedCopy {
  const _OwnerAccessUpdatedCopy({
    required this.title,
    required this.description,
    required this.primaryCta,
    required this.icon,
    required this.iconColor,
    this.secondaryCta,
  });

  final String title;
  final String description;
  final String primaryCta;
  final String? secondaryCta;
  final IconData icon;
  final Color iconColor;
}
