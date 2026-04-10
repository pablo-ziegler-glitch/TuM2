import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../owner/providers/owner_providers.dart';
import '../domain/pharmacy_duty_flow_models.dart';
import '../providers/pharmacy_duty_flow_providers.dart';
import '../services/pharmacy_duty_analytics.dart';
import '../services/pharmacy_duty_command_service.dart';

class ReportDutyIncidentScreen extends ConsumerStatefulWidget {
  const ReportDutyIncidentScreen({
    super.key,
    required this.dutyId,
  });

  final String dutyId;

  @override
  ConsumerState<ReportDutyIncidentScreen> createState() =>
      _ReportDutyIncidentScreenState();
}

class _ReportDutyIncidentScreenState
    extends ConsumerState<ReportDutyIncidentScreen> {
  PharmacyDutyIncidentType _selectedType = PharmacyDutyIncidentType.powerOutage;
  final TextEditingController _noteController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ownerMerchantAsync = ref.watch(ownerMerchantProvider);
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF9F7),
        elevation: 0,
        title: const Text(
          'Reportar inconveniente',
          style: AppTextStyles.headingSm,
        ),
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
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary500),
        ),
        error: (_, __) => _buildError('No pudimos validar tu comercio.'),
        data: (resolution) {
          final merchant = resolution.primaryMerchant;
          if (merchant == null) {
            return _buildError(
                'No encontramos un comercio asociado a tu usuario.');
          }
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                  children: [
                    Text(
                      '¿Qué está ocurriendo?',
                      style: AppTextStyles.headingLg.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Selecciona el inconveniente para priorizar la cobertura necesaria de inmediato.',
                      style: AppTextStyles.bodyMd
                          .copyWith(color: AppColors.neutral700),
                    ),
                    const SizedBox(height: 14),
                    GridView.count(
                      crossAxisCount: 2,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _incidentTile(
                          type: PharmacyDutyIncidentType.powerOutage,
                          icon: Icons.bolt,
                        ),
                        _incidentTile(
                          type: PharmacyDutyIncidentType.staffShortage,
                          icon: Icons.person_off,
                        ),
                        _incidentTile(
                          type: PharmacyDutyIncidentType.technicalIssue,
                          icon: Icons.handyman,
                        ),
                        _incidentTile(
                          type: PharmacyDutyIncidentType.other,
                          icon: Icons.add_photo_alternate_outlined,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'DETALLES ADICIONALES (OPCIONAL)',
                      style: AppTextStyles.bodyXs.copyWith(
                        color: AppColors.neutral700,
                        letterSpacing: 0.6,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _noteController,
                      enabled: !_submitting,
                      maxLength: 500,
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText: 'Describe brevemente la situación...',
                        filled: true,
                        fillColor: AppColors.neutral100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.neutral100),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF0D2232), Color(0xFF1E4F6D)],
                              ),
                            ),
                            child: const Icon(
                              Icons.monitor_heart_outlined,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'SINCRONIZACIÓN',
                                  style: AppTextStyles.bodyXs.copyWith(
                                    color: AppColors.secondary500,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Su reporte será notificado inmediatamente a la central de operaciones 24/7.',
                                  style: AppTextStyles.bodySm.copyWith(
                                    color: AppColors.neutral700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _error!,
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
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _submitting
                          ? null
                          : () => _submit(
                                zoneId: merchant.zoneId,
                                merchantId: merchant.id,
                              ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.warning_amber_rounded),
                      label: Text(
                        _submitting ? 'Solicitando...' : 'Solicitar cobertura',
                        style: AppTextStyles.labelMd.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _incidentTile({
    required PharmacyDutyIncidentType type,
    required IconData icon,
  }) {
    final selected = type == _selectedType;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: _submitting ? null : () => setState(() => _selectedType = type),
      child: Ink(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.primary500 : AppColors.neutral100,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.neutral100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.primary500),
            ),
            const Spacer(),
            Text(
              incidentTypeLabel(type),
              style: AppTextStyles.labelMd.copyWith(
                color: AppColors.neutral900,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

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

  Future<void> _submit({
    required String zoneId,
    required String merchantId,
  }) async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(pharmacyDutyCommandServiceProvider).reportIncident(
            dutyId: widget.dutyId,
            incidentType: _selectedType,
            note: _noteController.text.trim().isEmpty
                ? null
                : _noteController.text.trim(),
          );
      await PharmacyDutyFlowAnalytics.logIncidentReported(
        zoneId: zoneId,
        merchantRef: merchantId,
      );
      if (!mounted) return;
      context.go(
        AppRoutes.ownerPharmacyDutySelectCandidatesPath(widget.dutyId),
      );
    } on PharmacyDutyCommandException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }
}
