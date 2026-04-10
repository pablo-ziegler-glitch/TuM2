import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../owner/providers/owner_providers.dart';
import '../providers/pharmacy_duty_flow_providers.dart';
import '../services/pharmacy_duty_analytics.dart';
import '../services/pharmacy_duty_command_service.dart';

class UpcomingDutyConfirmationScreen extends ConsumerStatefulWidget {
  const UpcomingDutyConfirmationScreen({super.key});

  @override
  ConsumerState<UpcomingDutyConfirmationScreen> createState() =>
      _UpcomingDutyConfirmationScreenState();
}

class _UpcomingDutyConfirmationScreenState
    extends ConsumerState<UpcomingDutyConfirmationScreen> {
  bool _submitting = false;
  String? _message;
  bool _isError = false;

  @override
  Widget build(BuildContext context) {
    final ownerMerchantAsync = ref.watch(ownerMerchantProvider);
    final dateFormat = DateFormat('EEEE d MMMM · HH:mm', 'es');

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF9F7),
        elevation: 0,
        title: const Text('TuM2', style: AppTextStyles.headingSm),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.more_vert, color: AppColors.primary500),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFEDECEA)),
        ),
      ),
      body: ownerMerchantAsync.when(
        loading: _buildLoading,
        error: (_, __) => _buildError('No pudimos cargar tu comercio.'),
        data: (resolution) {
          final merchant = resolution.primaryMerchant;
          if (merchant == null) {
            return _buildError(
                'No encontramos un comercio asociado a tu usuario.');
          }
          final upcomingDutyAsync =
              ref.watch(upcomingOwnerDutyProvider(merchant.id));
          return upcomingDutyAsync.when(
            loading: _buildLoading,
            error: (_, __) =>
                _buildError('No pudimos consultar tu próxima guardia.'),
            data: (duty) {
              if (duty == null) {
                return _buildError('No tenés guardias próximas programadas.');
              }
              PharmacyDutyFlowAnalytics.logConfirmationPromptSeen(
                zoneId: duty.zoneId,
                merchantRef: merchant.id,
              );
              return Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                      children: [
                        Text(
                          'Tu zona cuenta con vos',
                          style: AppTextStyles.headingLg.copyWith(
                            fontSize: 44 / 2,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Confirmá tu disponibilidad para asegurar la cobertura operativa en el sector asignado.',
                          style: AppTextStyles.bodyMd.copyWith(
                            color: AppColors.neutral700,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _DutyCard(
                          dateLabel: _humanDate(duty.dateKey),
                          timeLabel: _buildRange(
                              dateFormat, duty.startsAt, duty.endsAt),
                          zoneLabel: duty.zoneId,
                        ),
                        const SizedBox(height: 12),
                        const Row(
                          children: [
                            Expanded(
                              child: _MiniInfoCard(
                                icon: Icons.verified_user,
                                label: 'Estado de equipo listo',
                              ),
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: _MiniInfoCard(
                                icon: Icons.bolt,
                                label: 'Protocolo de respuesta activo',
                              ),
                            ),
                          ],
                        ),
                        if (_message != null) ...[
                          const SizedBox(height: 12),
                          _FeedbackBanner(
                              message: _message!, isError: _isError),
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
                            child: ElevatedButton.icon(
                              onPressed: _submitting || !duty.canConfirm
                                  ? null
                                  : () => _confirmDuty(
                                        dutyId: duty.dutyId,
                                        zoneId: duty.zoneId,
                                        merchantId: merchant.id,
                                      ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary500,
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(52),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              icon: const Icon(Icons.check_circle, size: 20),
                              label: Text(
                                _submitting
                                    ? 'Confirmando...'
                                    : 'Confirmar guardia',
                                style: AppTextStyles.labelMd.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _submitting || !duty.canReportIncident
                                  ? null
                                  : () => context.push(
                                        AppRoutes
                                            .ownerPharmacyDutyIncidentReportPath(
                                          duty.dutyId,
                                        ),
                                      ),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(52),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                side: const BorderSide(
                                    color: AppColors.neutral300),
                              ),
                              icon: const Icon(Icons.report_problem),
                              label: const Text('Reportar inconveniente'),
                            ),
                          ),
                          TextButton(
                            onPressed: _submitting
                                ? null
                                : () => context.push(
                                      AppRoutes.ownerPharmacyDutyTrackingPath(
                                          duty.dutyId),
                                    ),
                            child: const Text('Ver seguimiento de cobertura'),
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
      ),
    );
  }

  Widget _buildLoading() => const Center(
        child: CircularProgressIndicator(color: AppColors.primary500),
      );

  Widget _buildError(String message) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            message,
            style: AppTextStyles.bodyMd,
            textAlign: TextAlign.center,
          ),
        ),
      );

  String _buildRange(
    DateFormat dateFormat,
    DateTime? startsAt,
    DateTime? endsAt,
  ) {
    if (startsAt == null || endsAt == null) return 'Horario no disponible';
    return '${DateFormat('HH:mm').format(startsAt.toLocal())} - '
        '${DateFormat('HH:mm').format(endsAt.toLocal())}';
  }

  String _humanDate(String dateKey) {
    try {
      final parsed = DateTime.parse(dateKey);
      return DateFormat("EEEE d MMM", 'es').format(parsed.toLocal());
    } catch (_) {
      return dateKey;
    }
  }

  Future<void> _confirmDuty({
    required String dutyId,
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
          .confirmPharmacyDuty(dutyId: dutyId);
      await PharmacyDutyFlowAnalytics.logDutyConfirmed(
        zoneId: zoneId,
        merchantRef: merchantId,
      );
      ref.invalidate(upcomingOwnerDutyProvider(merchantId));
      if (!mounted) return;
      setState(() {
        _message = 'Guardia confirmada correctamente.';
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

class _DutyCard extends StatelessWidget {
  const _DutyCard({
    required this.dateLabel,
    required this.timeLabel,
    required this.zoneLabel,
  });

  final String dateLabel;
  final String timeLabel;
  final String zoneLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.neutral100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'GUARDIA PROGRAMADA',
            style: AppTextStyles.bodyXs.copyWith(
              color: AppColors.secondary500,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            dateLabel,
            style: AppTextStyles.headingMd.copyWith(
              fontSize: 36 / 2,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.neutral100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.neutral50,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child:
                      const Icon(Icons.schedule, color: AppColors.primary500),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Horario de turno',
                      style: AppTextStyles.bodySm.copyWith(
                        color: AppColors.neutral900,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      timeLabel,
                      style: AppTextStyles.headingSm.copyWith(
                        color: AppColors.primary500,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.neutral50,
              borderRadius: BorderRadius.circular(10),
              border: const Border(
                  left: BorderSide(color: AppColors.secondary500, width: 4)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ZONA ASIGNADA',
                        style: AppTextStyles.bodyXs.copyWith(
                          color: AppColors.secondary500,
                          letterSpacing: 0.8,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        zoneLabel,
                        style: AppTextStyles.labelMd.copyWith(
                          color: AppColors.neutral900,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.map, color: AppColors.neutral700),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniInfoCard extends StatelessWidget {
  const _MiniInfoCard({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary500),
          const SizedBox(height: 8),
          Text(
            label,
            style: AppTextStyles.bodySm.copyWith(
              color: AppColors.neutral900,
              fontWeight: FontWeight.w500,
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
  });

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final fg = isError ? AppColors.errorFg : AppColors.successFg;
    final bg = isError ? AppColors.errorBg : AppColors.successBg;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        message,
        style: AppTextStyles.bodySm.copyWith(color: fg),
      ),
    );
  }
}
