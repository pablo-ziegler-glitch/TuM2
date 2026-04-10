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

class CoverageInvitationScreen extends ConsumerStatefulWidget {
  const CoverageInvitationScreen({
    super.key,
    required this.requestId,
  });

  final String requestId;

  @override
  ConsumerState<CoverageInvitationScreen> createState() =>
      _CoverageInvitationScreenState();
}

class _CoverageInvitationScreenState
    extends ConsumerState<CoverageInvitationScreen> {
  bool _submitting = false;
  String? _message;

  @override
  Widget build(BuildContext context) {
    final ownerMerchantAsync = ref.watch(ownerMerchantProvider);
    final invitationAsync =
        ref.watch(invitationDetailProvider(widget.requestId));

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF9F7),
        elevation: 0,
        title: const Text('Duty Reassignment', style: AppTextStyles.headingSm),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.more_vert, color: AppColors.neutral900),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFEDECEA)),
        ),
      ),
      body: ownerMerchantAsync.when(
        loading: _loading,
        error: (_, __) => _error('No pudimos validar tu comercio.'),
        data: (ownerResolution) {
          final ownerMerchant = ownerResolution.primaryMerchant;
          if (ownerMerchant == null)
            return _error('No encontramos un comercio asociado.');

          return invitationAsync.when(
            loading: _loading,
            error: (_, __) => _error('No pudimos cargar la invitación.'),
            data: (invitation) {
              if (invitation == null)
                return _error('La invitación no está disponible.');
              final canRespond =
                  invitation.request.status == 'pending' && !_submitting;

              return Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFDECEC),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'PRIORIDAD ALTA',
                              style: AppTextStyles.bodyXs.copyWith(
                                color: AppColors.errorFg,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Solicitud de cobertura urgente',
                          style: AppTextStyles.headingLg.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Una farmacia cercana requiere asistencia para cubrir su próximo turno obligatorio.',
                          style: AppTextStyles.bodyMd
                              .copyWith(color: AppColors.neutral700),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: const Border(
                              left: BorderSide(
                                  color: AppColors.primary500, width: 4),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'FARMACIA DE ORIGEN',
                                      style: AppTextStyles.bodyXs.copyWith(
                                        color: AppColors.primary500,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.7,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      invitation.originMerchantName,
                                      style: AppTextStyles.headingSm.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      invitation.request.originMerchantId,
                                      style: AppTextStyles.bodySm.copyWith(
                                        color: AppColors.neutral700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: AppColors.neutral100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.local_pharmacy,
                                  color: AppColors.primary500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          height: 124,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF0C2132), Color(0xFF114D72)],
                            ),
                          ),
                          child: Stack(
                            children: [
                              const Center(
                                child: Icon(
                                  Icons.place_outlined,
                                  color: Colors.white,
                                  size: 48,
                                ),
                              ),
                              Positioned(
                                left: 10,
                                bottom: 10,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    '▲ ${invitation.request.distanceKm.toStringAsFixed(1)} km de distancia',
                                    style: AppTextStyles.bodyXs.copyWith(
                                      color: AppColors.neutral900,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _metaCard(
                                icon: Icons.calendar_today_outlined,
                                title: 'FECHA DEL TURNO',
                                value: invitation.duty.dateKey,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _metaCard(
                                icon: Icons.access_time,
                                title: 'HORARIO',
                                value: _timeLabel(
                                  invitation.duty.startsAt,
                                  invitation.duty.endsAt,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFE6E6),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 2),
                                child: Icon(
                                  Icons.warning_rounded,
                                  color: AppColors.errorFg,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Aviso legal: Si aceptás, vas a figurar oficialmente como farmacia de turno ante el Colegio de Farmacéuticos y las autoridades locales.',
                                  style: AppTextStyles.bodySm.copyWith(
                                    color: AppColors.neutral900,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_message != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            _message!,
                            style: AppTextStyles.bodySm.copyWith(
                              color: AppColors.errorFg,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
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
                              onPressed: canRespond
                                  ? () => _respond(
                                        action: 'accept',
                                        zoneId: invitation.duty.zoneId,
                                        merchantRef: ownerMerchant.id,
                                        distanceBucket: _distanceBucket(
                                          invitation.request.distanceKm,
                                        ),
                                      )
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.secondary500,
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(52),
                              ),
                              icon: const Icon(Icons.check_circle),
                              label: const Text('Aceptar cobertura'),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: canRespond
                                  ? () => _respond(
                                        action: 'reject',
                                        zoneId: invitation.duty.zoneId,
                                        merchantRef: ownerMerchant.id,
                                        distanceBucket: '',
                                      )
                                  : null,
                              child: const Text('Rechazar'),
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

  Widget _metaCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.neutral700),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.bodyXs.copyWith(
                    color: AppColors.neutral700,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  value,
                  style: AppTextStyles.labelMd.copyWith(
                    color: AppColors.neutral900,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _timeLabel(DateTime? startsAt, DateTime? endsAt) {
    if (startsAt == null || endsAt == null) return 'Sin horario';
    final from = TimeOfDay.fromDateTime(startsAt.toLocal()).format(context);
    final to = TimeOfDay.fromDateTime(endsAt.toLocal()).format(context);
    return '$from - $to';
  }

  String _distanceBucket(double distanceKm) {
    if (distanceKm <= 2) return '0_2km';
    if (distanceKm <= 5) return '2_5km';
    if (distanceKm <= 10) return '5_10km';
    return '10km_plus';
  }

  Future<void> _respond({
    required String action,
    required String zoneId,
    required String merchantRef,
    required String distanceBucket,
  }) async {
    setState(() {
      _submitting = true;
      _message = null;
    });
    try {
      final requestStatus = await ref
          .read(pharmacyDutyCommandServiceProvider)
          .respondToReassignmentRequest(
            requestId: widget.requestId,
            action: action,
          );
      if (action == 'accept') {
        await PharmacyDutyFlowAnalytics.logRequestAccepted(
          zoneId: zoneId,
          merchantRef: merchantRef,
          distanceBucket: distanceBucket,
        );
        await PharmacyDutyFlowAnalytics.logDutyReassignedSuccessfully(
          zoneId: zoneId,
          merchantRef: merchantRef,
        );
      } else {
        await PharmacyDutyFlowAnalytics.logRequestRejected(
          zoneId: zoneId,
          merchantRef: merchantRef,
        );
      }
      if (!mounted) return;
      context.go(
        AppRoutes.ownerPharmacyDutyCoverageResultPath(
          status: requestStatus,
          action: action,
        ),
      );
    } on PharmacyDutyCommandException catch (error) {
      if (!mounted) return;
      setState(() => _message = error.message);
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }
}
