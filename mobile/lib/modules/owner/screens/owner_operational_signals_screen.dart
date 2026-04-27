import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_notifier.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../analytics/owner_operational_signals_analytics.dart';
import '../models/operational_signals.dart';
import '../providers/operational_signals_provider.dart';
import '../providers/owner_providers.dart';

class OwnerOperationalSignalsScreen extends ConsumerStatefulWidget {
  const OwnerOperationalSignalsScreen({super.key});

  @override
  ConsumerState<OwnerOperationalSignalsScreen> createState() =>
      _OwnerOperationalSignalsScreenState();
}

class _OwnerOperationalSignalsScreenState
    extends ConsumerState<OwnerOperationalSignalsScreen> {
  final _messageController = TextEditingController();
  bool _openedLogged = false;
  bool _previewLogged = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider).authState;
    final ownerMerchantAsync = ref.watch(ownerMerchantProvider);
    final ownerUserId =
        authState is AuthAuthenticated ? authState.user.uid : null;

    if (ownerUserId == null) {
      return const _SignalsScaffold(
        child: _ErrorState(
          message: 'Necesitás iniciar sesión para editar señales operativas.',
        ),
      );
    }

    return ownerMerchantAsync.when(
      loading: () => const _SignalsScaffold(
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary500),
        ),
      ),
      error: (_, __) => _SignalsScaffold(
        child: _ErrorState(
          message: 'No pudimos validar tu comercio.',
          onRetry: () => ref.invalidate(ownerMerchantProvider),
        ),
      ),
      data: (resolution) {
        if (authState is AuthAuthenticated && authState.ownerPending) {
          return const _SignalsScaffold(
            child: _PendingBlockedCard(),
          );
        }

        final merchant = resolution.primaryMerchant;
        if (merchant == null) {
          return const _SignalsScaffold(
            child: _ErrorState(
              message: 'No encontramos un comercio asociado a tu usuario.',
            ),
          );
        }

        final scope = OwnerOperationalSignalsScope(
          merchantId: merchant.id,
          ownerUserId: ownerUserId,
        );
        final state = ref.watch(operationalSignalsNotifierProvider(scope));
        final notifier =
            ref.read(operationalSignalsNotifierProvider(scope).notifier);
        _logOpenedOnce(merchant.id);
        _logPreviewOnce(
          merchantId: merchant.id,
          signalType: state.draftSignalType,
          isInitialLoading: state.isInitialLoading,
        );

        if (_messageController.text != state.draftMessage) {
          _messageController.text = state.draftMessage;
          _messageController.selection = TextSelection.collapsed(
            offset: _messageController.text.length,
          );
        }

        final showsConnectionError =
            state.hasError && (state.message ?? '').contains('conexión');
        final showsEmptyOperationalState = !state.isInitialLoading &&
            !state.hasActiveSignal &&
            state.draftSignalType == OperationalSignalType.none &&
            !showsConnectionError;

        return _SignalsScaffold(
          child: RefreshIndicator(
            onRefresh: notifier.load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
              children: [
                _MerchantHeader(
                  merchantName: merchant.name,
                  signal: state.currentSignal,
                ),
                const SizedBox(height: 14),
                if (state.isInitialLoading)
                  const Padding(
                    padding: EdgeInsets.only(top: 42),
                    child: Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary500),
                    ),
                  )
                else if (showsConnectionError)
                  _ConnectionErrorCard(onRetry: notifier.load)
                else if (showsEmptyOperationalState)
                  _EmptySignalsCard(
                    onCreatePressed: () => notifier
                        .setDraftSignalType(OperationalSignalType.vacation),
                  )
                else
                  _OperationalFormSection(
                    state: state,
                    messageController: _messageController,
                    onTypeChanged: notifier.setDraftSignalType,
                    onMessageChanged: notifier.setDraftMessage,
                    onSave: notifier.saveDraft,
                    onDeactivate: () => _confirmDeactivate(
                      context: context,
                      onConfirm: notifier.clearSignal,
                    ),
                    onDismissFeedback: notifier.clearFeedback,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _logOpenedOnce(String merchantId) {
    if (_openedLogged) return;
    _openedLogged = true;
    unawaited(
      OwnerOperationalSignalsAnalytics.logOpened(merchantId: merchantId),
    );
  }

  Future<void> _confirmDeactivate({
    required BuildContext context,
    required Future<void> Function() onConfirm,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('¿Desactivar aviso?'),
          content: const Text(
            'Tu Comercio volverá a mostrarse según tus horarios habituales.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton.tonal(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Desactivar aviso'),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      await onConfirm();
    }
  }

  void _logPreviewOnce({
    required String merchantId,
    required OperationalSignalType signalType,
    required bool isInitialLoading,
  }) {
    if (_previewLogged || isInitialLoading) return;
    _previewLogged = true;
    unawaited(
      OwnerOperationalSignalsAnalytics.logOperationalPreviewViewed(
        merchantId: merchantId,
        signalType: signalType,
      ),
    );
  }
}

class _SignalsScaffold extends StatelessWidget {
  const _SignalsScaffold({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text(
          'Señales operativas',
          style: AppTextStyles.headingSm.copyWith(
            color: AppColors.primary600,
          ),
        ),
      ),
      body: child,
    );
  }
}

class _MerchantHeader extends StatelessWidget {
  const _MerchantHeader({
    required this.merchantName,
    required this.signal,
  });

  final String merchantName;
  final OwnerOperationalSignal signal;

  @override
  Widget build(BuildContext context) {
    final hasSignal = signal.hasActiveSignal;
    final statusText =
        hasSignal ? signal.signalType.publicLabel : 'Sin señal activa';
    final chipColor = signal.forceClosed
        ? AppColors.errorFg.withValues(alpha: 0.12)
        : AppColors.primary100;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary600, AppColors.primary500],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            merchantName,
            style: AppTextStyles.headingMd.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: chipColor,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              statusText,
              style: AppTextStyles.labelSm.copyWith(
                color: Colors.white,
                letterSpacing: 0.4,
              ),
            ),
          ),
          if ((signal.message ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              signal.message!.trim(),
              style: AppTextStyles.bodySm.copyWith(color: Colors.white70),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptySignalsCard extends StatelessWidget {
  const _EmptySignalsCard({
    required this.onCreatePressed,
  });

  final VoidCallback onCreatePressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 20),
      decoration: BoxDecoration(
        color: AppColors.merchantSurfaceLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Señales operativas',
            style:
                AppTextStyles.headingMd.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Avisá algo puntual para que los Vecinos vean información actualizada.',
            style: AppTextStyles.bodyMd.copyWith(color: AppColors.neutral700),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: onCreatePressed,
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('Avisar cambio'),
          ),
          const SizedBox(height: 16),
          const _TipTile(
            icon: Icons.beach_access,
            title: 'Cerrado por vacaciones',
            body: 'Para varios días o cierres estacionales.',
          ),
          const SizedBox(height: 10),
          const _TipTile(
            icon: Icons.lock_clock,
            title: 'Cerrado temporalmente',
            body: 'Para un cierre puntual por mantenimiento o imprevistos.',
          ),
          const SizedBox(height: 10),
          const _TipTile(
            icon: Icons.update,
            title: 'Abre más tarde',
            body: 'Para avisar una demora puntual en la apertura.',
          ),
        ],
      ),
    );
  }
}

class _TipTile extends StatelessWidget {
  const _TipTile({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.primary600),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.labelMd),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: AppTextStyles.bodyXs
                      .copyWith(color: AppColors.neutral700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OperationalFormSection extends StatelessWidget {
  const _OperationalFormSection({
    required this.state,
    required this.messageController,
    required this.onTypeChanged,
    required this.onMessageChanged,
    required this.onSave,
    required this.onDeactivate,
    required this.onDismissFeedback,
  });

  final OperationalSignalsState state;
  final TextEditingController messageController;
  final ValueChanged<OperationalSignalType> onTypeChanged;
  final ValueChanged<String> onMessageChanged;
  final VoidCallback onSave;
  final VoidCallback onDeactivate;
  final VoidCallback onDismissFeedback;

  @override
  Widget build(BuildContext context) {
    final isSaving = state.isSaving;
    final message = state.validationError ?? state.message;
    final showFeedback =
        message != null && (state.hasError || state.hasSuccess);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Señales operativas',
          style: AppTextStyles.headingMd.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          'Avisá algo puntual para que los Vecinos vean información actualizada.',
          style: AppTextStyles.bodySm.copyWith(color: AppColors.neutral700),
        ),
        const SizedBox(height: 12),
        _SignalTypeCards(
          selected: state.draftSignalType,
          onChanged: onTypeChanged,
        ),
        const SizedBox(height: 16),
        const Text(
          'Mensaje para los Vecinos',
          style: AppTextStyles.labelMd,
        ),
        const SizedBox(height: 8),
        Text(
          'Opcional. Máximo $operationalSignalMaxMessageLength caracteres.',
          style: AppTextStyles.bodyXs.copyWith(color: AppColors.neutral700),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: messageController,
          maxLength: operationalSignalMaxMessageLength,
          enabled: !isSaving,
          minLines: 3,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: 'Ej: Hoy abrimos con demora',
            border: OutlineInputBorder(),
          ),
          onChanged: onMessageChanged,
        ),
        _PreviewCard(
          signalType: state.draftSignalType,
          message: state.draftMessage,
        ),
        if (showFeedback) ...[
          const SizedBox(height: 10),
          _FeedbackBanner(
            message: message,
            isError: state.hasError,
            isSuccess: state.hasSuccess,
            onDismiss: onDismissFeedback,
          ),
        ],
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: isSaving ? null : onSave,
            icon: Icon(isSaving ? Icons.hourglass_top : Icons.send),
            label: Text(isSaving ? 'Guardando...' : 'Activar aviso'),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: isSaving || !state.hasActiveSignal ? null : onDeactivate,
            child: const Text('Desactivar aviso'),
          ),
        ),
        if (state.hasSuccess) ...[
          const SizedBox(height: 10),
          _SuccessCard(lastSavedAt: state.lastSuccessfulSaveAt),
        ],
      ],
    );
  }
}

class _SignalTypeCards extends StatelessWidget {
  const _SignalTypeCards({
    required this.selected,
    required this.onChanged,
  });

  final OperationalSignalType selected;
  final ValueChanged<OperationalSignalType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SignalTypeCard(
          title: 'Cerrado por vacaciones',
          subtitle: 'Para varios días.',
          icon: Icons.beach_access,
          tone: AppColors.primary600,
          type: OperationalSignalType.vacation,
          selected: selected,
          onChanged: onChanged,
        ),
        const SizedBox(height: 8),
        _SignalTypeCard(
          title: 'Cerrado temporalmente',
          subtitle: 'Para un cierre puntual.',
          icon: Icons.lock_clock,
          tone: AppColors.errorFg,
          type: OperationalSignalType.temporaryClosure,
          selected: selected,
          onChanged: onChanged,
        ),
        const SizedBox(height: 8),
        _SignalTypeCard(
          title: 'Abre más tarde',
          subtitle: 'Para avisar una demora hoy.',
          icon: Icons.schedule,
          tone: AppColors.tertiary700,
          type: OperationalSignalType.delay,
          selected: selected,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _SignalTypeCard extends StatelessWidget {
  const _SignalTypeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.tone,
    required this.type,
    required this.selected,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color tone;
  final OperationalSignalType type;
  final OperationalSignalType selected;
  final ValueChanged<OperationalSignalType> onChanged;

  @override
  Widget build(BuildContext context) {
    final isSelected = selected == type;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => onChanged(type),
      child: Ink(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : AppColors.merchantSurfaceLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary600 : AppColors.neutral200,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: tone.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: tone),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.labelMd),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTextStyles.bodyXs
                        .copyWith(color: AppColors.neutral700),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: AppColors.primary600),
          ],
        ),
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.signalType,
    required this.message,
  });

  final OperationalSignalType signalType;
  final String message;

  @override
  Widget build(BuildContext context) {
    final resolvedLabel = switch (signalType) {
      OperationalSignalType.vacation => 'Cerrado por vacaciones',
      OperationalSignalType.temporaryClosure => 'Cerrado temporalmente',
      OperationalSignalType.delay => 'Abre más tarde',
      OperationalSignalType.none => 'Sin señal activa',
    };
    final previewMessage =
        message.trim().isEmpty ? resolvedLabel : message.trim();

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.visibility_outlined,
                  size: 16, color: AppColors.neutral600),
              const SizedBox(width: 6),
              Text(
                'Así se verá en Tu zona.',
                style:
                    AppTextStyles.labelSm.copyWith(color: AppColors.neutral700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            previewMessage,
            style: AppTextStyles.bodySm.copyWith(color: AppColors.neutral900),
          ),
          const SizedBox(height: 8),
          Text(
            'Los avisos activos tienen prioridad sobre el horario habitual.',
            style: AppTextStyles.bodyXs.copyWith(color: AppColors.neutral700),
          ),
        ],
      ),
    );
  }
}

class _ConnectionErrorCard extends StatelessWidget {
  const _ConnectionErrorCard({
    required this.onRetry,
  });

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Error de conexión',
            style:
                AppTextStyles.headingMd.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'No logramos conectar con el servidor. Reintentá para continuar.',
            style: AppTextStyles.bodySm.copyWith(color: AppColors.neutral700),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar conexión'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuccessCard extends StatelessWidget {
  const _SuccessCard({
    required this.lastSavedAt,
  });

  final DateTime? lastSavedAt;

  @override
  Widget build(BuildContext context) {
    final savedLabel = lastSavedAt == null
        ? 'Actualizada recientemente'
        : 'Actualizada: ${lastSavedAt!.hour.toString().padLeft(2, '0')}:${lastSavedAt!.minute.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.successBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: AppColors.successFg),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Aviso actualizado. $savedLabel',
              style: AppTextStyles.bodySm.copyWith(color: AppColors.successFg),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedbackBanner extends StatelessWidget {
  const _FeedbackBanner({
    required this.message,
    required this.isError,
    required this.isSuccess,
    required this.onDismiss,
  });

  final String? message;
  final bool isError;
  final bool isSuccess;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    if (message == null || (!isError && !isSuccess)) {
      return const SizedBox.shrink();
    }

    final bgColor = isError ? AppColors.errorBg : AppColors.successBg;
    final fgColor = isError ? AppColors.errorFg : AppColors.successFg;
    final icon = isError ? Icons.error_outline : Icons.check_circle_outline;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: fgColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message!,
              style: AppTextStyles.bodySm.copyWith(color: fgColor),
            ),
          ),
          IconButton(
            onPressed: onDismiss,
            icon: Icon(Icons.close, size: 18, color: fgColor),
            splashRadius: 18,
            tooltip: 'Cerrar',
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    this.onRetry,
  });

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.errorFg, size: 28),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMd.copyWith(color: AppColors.neutral800),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: onRetry,
                child: const Text('Reintentar'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PendingBlockedCard extends StatelessWidget {
  const _PendingBlockedCard();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.hourglass_top_rounded,
              size: 40,
              color: AppColors.neutral600,
            ),
            SizedBox(height: 12),
            Text(
              'Tu comercio está en revisión',
              style: AppTextStyles.headingSm,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'Cuando se apruebe, vas a poder editar horarios y avisos operativos.',
              style: AppTextStyles.bodySm,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
