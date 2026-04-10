import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../owner/providers/owner_providers.dart';
import '../providers/pharmacy_duty_flow_providers.dart';
import '../services/pharmacy_duty_analytics.dart';
import '../services/pharmacy_duty_command_service.dart';

class ReassignmentTrackingScreen extends ConsumerStatefulWidget {
  const ReassignmentTrackingScreen({
    super.key,
    required this.dutyId,
  });

  final String dutyId;

  @override
  ConsumerState<ReassignmentTrackingScreen> createState() =>
      _ReassignmentTrackingScreenState();
}

class _ReassignmentTrackingScreenState
    extends ConsumerState<ReassignmentTrackingScreen> {
  bool _submitting = false;
  String? _message;
  bool _isError = false;

  @override
  Widget build(BuildContext context) {
    final ownerMerchantAsync = ref.watch(ownerMerchantProvider);
    final openRoundAsync = ref.watch(dutyOpenRoundProvider(widget.dutyId));

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF9F7),
        elevation: 0,
        title: const Text(
          'Tracking de solicitud',
          style: AppTextStyles.headingSm,
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.more_vert, color: AppColors.primary500),
          ),
        ],
      ),
      body: ownerMerchantAsync.when(
        loading: _loading,
        error: (_, __) => _error('No pudimos validar tu comercio.'),
        data: (ownerResolution) {
          final merchant = ownerResolution.primaryMerchant;
          if (merchant == null)
            return _error('No encontramos un comercio asociado.');

          return openRoundAsync.when(
            loading: _loading,
            error: (_, __) => _error('No pudimos cargar la ronda activa.'),
            data: (round) {
              if (round == null) {
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                  children: [
                    _emptyCard(),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => context.push(
                        AppRoutes.ownerPharmacyDutySelectCandidatesPath(
                          widget.dutyId,
                        ),
                      ),
                      icon: const Icon(Icons.replay_outlined),
                      label: const Text('Iniciar nueva ronda'),
                    ),
                  ],
                );
              }

              final requestsAsync =
                  ref.watch(roundRequestsProvider(round.roundId));
              return requestsAsync.when(
                loading: _loading,
                error: (_, __) => _error('No pudimos cargar solicitudes.'),
                data: (requests) {
                  final hasPending =
                      requests.any((item) => item.status == 'pending');
                  if (!hasPending && round.status == 'open') {
                    PharmacyDutyFlowAnalytics.logRoundExpired(
                      zoneId: merchant.zoneId,
                      merchantRef: merchant.id,
                    );
                  }
                  return Column(
                    children: [
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                          children: [
                            Center(
                              child: Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF99EFE5),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.check_circle,
                                  color: Color(0xFF006A63),
                                  size: 32,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Enviamos tu solicitud',
                              style: AppTextStyles.headingLg.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Reasignación de turnos iniciada exitosamente.',
                              style: AppTextStyles.bodyMd.copyWith(
                                color: AppColors.neutral700,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: _statusCard(
                                    title: 'ESTADO GENERAL',
                                    value: hasPending
                                        ? 'Esperando respuesta'
                                        : 'Sin pendientes',
                                    tone: AppColors.primary500,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _statusCard(
                                    title: 'ID DE SOLICITUD',
                                    value: '#${round.roundId.substring(0, 8)}',
                                    tone: AppColors.neutral900,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'Farmacias invitadas',
                                        style: AppTextStyles.headingSm.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const Spacer(),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.neutral100,
                                          borderRadius:
                                              BorderRadius.circular(999),
                                        ),
                                        child: Text(
                                          '${requests.length} TOTAL',
                                          style: AppTextStyles.bodyXs.copyWith(
                                            color: AppColors.neutral700,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  ...requests.map(
                                    (item) => Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: AppColors.neutral50,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 36,
                                            height: 36,
                                            decoration: BoxDecoration(
                                              color: AppColors.neutral100,
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                            child: const Icon(
                                              Icons.local_pharmacy,
                                              size: 18,
                                              color: AppColors.primary500,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  item.candidateMerchantId,
                                                  style: AppTextStyles.labelMd
                                                      .copyWith(
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                                Text(
                                                  '${item.distanceKm.toStringAsFixed(1)} km',
                                                  style: AppTextStyles.bodyXs,
                                                ),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.neutral100,
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                            child: Text(
                                              item.status.toUpperCase(),
                                              style:
                                                  AppTextStyles.bodyXs.copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_message != null) ...[
                              const SizedBox(height: 8),
                              _feedback(_message!, _isError),
                            ],
                          ],
                        ),
                      ),
                      SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                          child: Column(
                            children: [
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () => context.push(
                                    AppRoutes.ownerPharmacyDutyTrackingPath(
                                      widget.dutyId,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    minimumSize: const Size.fromHeight(50),
                                    backgroundColor: AppColors.primary500,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('Ver estado detallado'),
                                ),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  onPressed: round.status == 'open'
                                      ? (_submitting
                                          ? null
                                          : () => _cancelRound(
                                                roundId: round.roundId,
                                                zoneId: merchant.zoneId,
                                                merchantId: merchant.id,
                                              ))
                                      : () => context.go(AppRoutes.home),
                                  child: Text(
                                    round.status == 'open'
                                        ? (_submitting
                                            ? 'Cancelando...'
                                            : 'Cancelar ronda')
                                        : 'Volver al inicio',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _loading() => const Center(
        child: CircularProgressIndicator(color: AppColors.primary500),
      );

  Widget _error(String message) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            message,
            style: AppTextStyles.bodyMd,
            textAlign: TextAlign.center,
          ),
        ),
      );

  Widget _emptyCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        'No hay ronda activa para este turno.',
        style: AppTextStyles.bodySm.copyWith(color: AppColors.neutral700),
      ),
    );
  }

  Widget _statusCard({
    required String title,
    required String value,
    required Color tone,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTextStyles.bodyXs.copyWith(
              color: AppColors.neutral700,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTextStyles.headingSm.copyWith(
              color: tone,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _feedback(String message, bool isError) {
    final fg = isError ? AppColors.errorFg : AppColors.successFg;
    final bg = isError ? AppColors.errorBg : AppColors.successBg;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(message, style: AppTextStyles.bodySm.copyWith(color: fg)),
    );
  }

  Future<void> _cancelRound({
    required String roundId,
    required String zoneId,
    required String merchantId,
  }) async {
    setState(() {
      _submitting = true;
      _message = null;
      _isError = false;
    });
    try {
      await ref
          .read(pharmacyDutyCommandServiceProvider)
          .cancelReassignmentRound(roundId: roundId);
      await PharmacyDutyFlowAnalytics.logRoundExpired(
        zoneId: zoneId,
        merchantRef: merchantId,
      );
      ref.invalidate(dutyOpenRoundProvider(widget.dutyId));
      if (!mounted) return;
      setState(() {
        _message = 'Ronda cancelada.';
        _isError = false;
      });
    } on PharmacyDutyCommandException catch (error) {
      if (!mounted) return;
      setState(() {
        _message = error.message;
        _isError = true;
      });
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }
}
