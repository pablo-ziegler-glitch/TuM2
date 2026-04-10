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
  bool _openedLogged = false;

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

        return _SignalsScaffold(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              _MerchantPreviewHeader(
                merchantName: merchant.name,
                signals: state.signals,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Señales operativas',
                      style: AppTextStyles.headingLg.copyWith(
                        color: AppColors.neutral900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Avisale a tus vecinos cómo estás atendiendo hoy',
                      style: AppTextStyles.bodySm.copyWith(
                        color: AppColors.neutral700,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _FeedbackBanner(
                      message: state.message,
                      isError: state.hasError,
                      isSuccess: state.hasSuccess,
                      onDismiss: notifier.clearFeedback,
                    ),
                    if (state.isInitialLoading) ...[
                      const SizedBox(height: 40),
                      const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary500,
                        ),
                      ),
                    ] else ...[
                      _EmergencyCloseCard(
                        value: state.signals.temporaryClosed,
                        isSaving: state.savingKeys
                            .contains(OperationalSignalKey.temporaryClosed),
                        onChanged: (value) => notifier.updateSignal(
                          key: OperationalSignalKey.temporaryClosed,
                          value: value,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _OpenNowManualCard(
                        value: state.signals.openNowManualOverride,
                        isDisabledByTemporaryClosed:
                            state.signals.temporaryClosed,
                        isSaving: state.savingKeys.contains(
                            OperationalSignalKey.openNowManualOverride),
                        onChanged: (value) => notifier.updateSignal(
                          key: OperationalSignalKey.openNowManualOverride,
                          value: value,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _ServicesCard(
                        hasDelivery: state.signals.hasDelivery,
                        acceptsWhatsappOrders:
                            state.signals.acceptsWhatsappOrders,
                        isSavingDelivery: state.savingKeys
                            .contains(OperationalSignalKey.hasDelivery),
                        isSavingWhatsapp: state.savingKeys.contains(
                            OperationalSignalKey.acceptsWhatsappOrders),
                        onDeliveryChanged: (value) => notifier.updateSignal(
                          key: OperationalSignalKey.hasDelivery,
                          value: value,
                        ),
                        onWhatsappChanged: (value) => notifier.updateSignal(
                          key: OperationalSignalKey.acceptsWhatsappOrders,
                          value: value,
                        ),
                      ),
                      const SizedBox(height: 24),
                      _AutoSaveFooter(
                        isSaving: state.isSavingAny,
                        lastSuccessfulSaveAt: state.lastSuccessfulSaveAt,
                      ),
                    ],
                  ],
                ),
              ),
            ],
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
        scrolledUnderElevation: 0,
        title: const Text('SignalHub', style: AppTextStyles.headingSm),
      ),
      body: child,
    );
  }
}

class _MerchantPreviewHeader extends StatelessWidget {
  const _MerchantPreviewHeader({
    required this.merchantName,
    required this.signals,
  });

  final String merchantName;
  final OperationalSignals signals;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primary500,
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ASÍ LO VEN TUS VECINOS',
            style: AppTextStyles.labelSm.copyWith(
              color: Colors.white70,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.storefront_outlined,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
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
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _PreviewChip(
                          label: signals.temporaryClosed
                              ? 'CERRADO TEMPORAL'
                              : 'ABIERTO AHORA',
                          color: signals.temporaryClosed
                              ? AppColors.errorFg.withValues(alpha: 0.25)
                              : AppColors.secondary500.withValues(alpha: 0.3),
                        ),
                        if (signals.hasDelivery)
                          const _PreviewChip(
                            label: 'DELIVERY',
                            color: Colors.white24,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PreviewChip extends StatelessWidget {
  const _PreviewChip({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSm.copyWith(
          color: Colors.white,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _EmergencyCloseCard extends StatelessWidget {
  const _EmergencyCloseCard({
    required this.value,
    required this.isSaving,
    required this.onChanged,
  });

  final bool value;
  final bool isSaving;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.errorBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.errorFg.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.errorFg),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Cerrado temporalmente',
                  style: AppTextStyles.labelMd.copyWith(
                    color: AppColors.errorFg,
                  ),
                ),
              ),
              _InlineSignalSwitch(
                value: value,
                isSaving: isSaving,
                onChanged: onChanged,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Si activás esto, no aparecerás como abierto en el mapa. Ideal para cierres de emergencia o feriados imprevistos.',
            style: AppTextStyles.bodySm.copyWith(color: AppColors.errorFg),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isSaving ? null : () => onChanged(!value),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.errorFg,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                value
                    ? 'Desactivar cierre temporal'
                    : 'Activar cierre temporal',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OpenNowManualCard extends StatelessWidget {
  const _OpenNowManualCard({
    required this.value,
    required this.isDisabledByTemporaryClosed,
    required this.isSaving,
    required this.onChanged,
  });

  final bool value;
  final bool isDisabledByTemporaryClosed;
  final bool isSaving;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.neutral100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.storefront_rounded, color: AppColors.primary500),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '¿Estás abierto ahora?',
                  style: AppTextStyles.labelMd,
                ),
              ),
              _InlineSignalSwitch(
                value: value,
                isSaving: isSaving,
                isDisabled: isDisabledByTemporaryClosed,
                onChanged: onChanged,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Esto reemplaza temporalmente tu horario configurado. Los vecinos verán que estás atendiendo aunque sea fuera de hora.',
            style: AppTextStyles.bodySm.copyWith(color: AppColors.neutral700),
          ),
          if (value) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'ESTADO: ABIERTO AHORA MANUAL',
                style: AppTextStyles.labelSm.copyWith(
                  color: AppColors.primary600,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ],
          if (isDisabledByTemporaryClosed) ...[
            const SizedBox(height: 12),
            Text(
              'Desactivá "Cerrado temporalmente" para habilitar esta opción.',
              style: AppTextStyles.bodyXs.copyWith(color: AppColors.neutral700),
            ),
          ],
        ],
      ),
    );
  }
}

class _ServicesCard extends StatelessWidget {
  const _ServicesCard({
    required this.hasDelivery,
    required this.acceptsWhatsappOrders,
    required this.isSavingDelivery,
    required this.isSavingWhatsapp,
    required this.onDeliveryChanged,
    required this.onWhatsappChanged,
  });

  final bool hasDelivery;
  final bool acceptsWhatsappOrders;
  final bool isSavingDelivery;
  final bool isSavingWhatsapp;
  final ValueChanged<bool> onDeliveryChanged;
  final ValueChanged<bool> onWhatsappChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.neutral100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.settings_suggest, color: AppColors.neutral600),
              SizedBox(width: 8),
              Text('Servicios y Pedidos', style: AppTextStyles.labelMd),
            ],
          ),
          const SizedBox(height: 16),
          _ServiceRow(
            title: '¿Hacés envíos?',
            subtitle:
                'Mostrar insignia DELIVERY en tu perfil para que todos lo sepan.',
            value: hasDelivery,
            isSaving: isSavingDelivery,
            onChanged: onDeliveryChanged,
          ),
          const SizedBox(height: 10),
          const Divider(color: AppColors.neutral100, height: 1),
          const SizedBox(height: 10),
          _ServiceRow(
            title: '¿Recibís pedidos por WhatsApp?',
            subtitle:
                'Activa el botón de contacto directo para que te escriban con un clic.',
            value: acceptsWhatsappOrders,
            isSaving: isSavingWhatsapp,
            onChanged: onWhatsappChanged,
          ),
        ],
      ),
    );
  }
}

class _ServiceRow extends StatelessWidget {
  const _ServiceRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.isSaving,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final bool isSaving;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.labelMd),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style:
                    AppTextStyles.bodyXs.copyWith(color: AppColors.neutral700),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        _InlineSignalSwitch(
          value: value,
          isSaving: isSaving,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _InlineSignalSwitch extends StatelessWidget {
  const _InlineSignalSwitch({
    required this.value,
    required this.isSaving,
    this.isDisabled = false,
    required this.onChanged,
  });

  final bool value;
  final bool isSaving;
  final bool isDisabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    if (isSaving) {
      return const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    return Switch.adaptive(
      value: value,
      onChanged: isDisabled ? null : onChanged,
      activeThumbColor: AppColors.primary500,
      activeTrackColor: AppColors.primary200,
    );
  }
}

class _AutoSaveFooter extends StatelessWidget {
  const _AutoSaveFooter({
    required this.isSaving,
    required this.lastSuccessfulSaveAt,
  });

  final bool isSaving;
  final DateTime? lastSuccessfulSaveAt;

  @override
  Widget build(BuildContext context) {
    final label = isSaving
        ? 'Guardando cambios...'
        : _buildLastUpdateLabel(lastSuccessfulSaveAt);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.successBg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.secondary200),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: AppColors.secondary500,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'DATO ACTUALIZADO',
                style: AppTextStyles.labelSm.copyWith(
                  color: AppColors.secondary700,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Los cambios se guardan automáticamente',
          style: AppTextStyles.bodySm.copyWith(color: AppColors.neutral800),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTextStyles.bodyXs.copyWith(color: AppColors.neutral600),
        ),
      ],
    );
  }

  String _buildLastUpdateLabel(DateTime? lastSuccessfulSaveAt) {
    if (lastSuccessfulSaveAt == null) {
      return 'Última actualización: pendiente';
    }
    final diff = DateTime.now().difference(lastSuccessfulSaveAt);
    if (diff.inSeconds < 5) {
      return 'Última actualización: recién ahora';
    }
    if (diff.inSeconds < 60) {
      return 'Última actualización: hace ${diff.inSeconds} segundos';
    }
    if (diff.inMinutes < 60) {
      return 'Última actualización: hace ${diff.inMinutes} minutos';
    }
    return 'Última actualización: hace ${diff.inHours} horas';
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
      margin: const EdgeInsets.only(bottom: 12),
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
            Text(
              message,
              style: AppTextStyles.bodyMd,
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary500,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Reintentar'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
