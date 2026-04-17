import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../owner/providers/owner_providers.dart';
import '../domain/pharmacy_duty_flow_models.dart';
import '../services/pharmacy_duty_analytics.dart';
import '../services/pharmacy_duty_command_service.dart';
import '../providers/pharmacy_duty_flow_providers.dart';

class SelectReplacementCandidatesScreen extends ConsumerStatefulWidget {
  const SelectReplacementCandidatesScreen({
    super.key,
    required this.dutyId,
  });

  final String dutyId;

  @override
  ConsumerState<SelectReplacementCandidatesScreen> createState() =>
      _SelectReplacementCandidatesScreenState();
}

class _SelectReplacementCandidatesScreenState
    extends ConsumerState<SelectReplacementCandidatesScreen> {
  bool _loading = true;
  bool _submitting = false;
  String? _error;
  List<DutyReplacementCandidate> _candidates = const [];
  int _maxCandidates = 5;
  String _zoneId = '';
  String _merchantRef = '';
  final Set<String> _selected = <String>{};

  @override
  void initState() {
    super.initState();
    _loadCandidates();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF9F7),
        elevation: 0,
        title:
            const Text('Cobertura de guardia', style: AppTextStyles.headingSm),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.more_vert, color: AppColors.primary500),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary500),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    children: [
                      Text(
                        'Elegí farmacias cercanas',
                        style: AppTextStyles.headingLg.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'La primera que acepte toma la guardia',
                        style: AppTextStyles.bodyMd.copyWith(
                          color: AppColors.neutral700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.location_on,
                                color: AppColors.secondary500, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              'RADIO 10 KM',
                              style: AppTextStyles.bodySm.copyWith(
                                color: AppColors.neutral700,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              'Ajustar',
                              style: AppTextStyles.bodySm.copyWith(
                                color: AppColors.primary500,
                                fontWeight: FontWeight.w700,
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
                      const SizedBox(height: 10),
                      if (_candidates.isEmpty)
                        _emptyState()
                      else
                        ..._candidates.map(_candidateTile),
                      const SizedBox(height: 12),
                      _mapPreview(),
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _selected.isEmpty || _submitting
                            ? null
                            : _createRound,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary500,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.send),
                        label: Text(
                          _submitting ? 'Enviando...' : 'Enviar solicitudes',
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
            ),
    );
  }

  Widget _emptyState() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.neutral100),
      ),
      child: Text(
        'No encontramos farmacias elegibles en el radio configurado.',
        style: AppTextStyles.bodySm.copyWith(color: AppColors.neutral700),
      ),
    );
  }

  Widget _candidateTile(DutyReplacementCandidate candidate) {
    final isSelected = _selected.contains(candidate.merchantId);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isSelected ? AppColors.primary500 : AppColors.neutral100,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.neutral100,
              borderRadius: BorderRadius.circular(8),
            ),
            child:
                const Icon(Icons.local_pharmacy, color: AppColors.primary500),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  candidate.merchantName,
                  style: AppTextStyles.labelMd.copyWith(
                    color: AppColors.neutral900,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  candidate.merchantId,
                  style: AppTextStyles.bodySm
                      .copyWith(color: AppColors.neutral700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '▼ ${candidate.distanceKm.toStringAsFixed(1)} km de distancia',
                  style: AppTextStyles.bodyXs.copyWith(
                    color: AppColors.secondary500,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Checkbox(
            value: isSelected,
            onChanged: _submitting
                ? null
                : (value) {
                    setState(() {
                      if (value == true) {
                        if (_selected.length >= _maxCandidates) return;
                        _selected.add(candidate.merchantId);
                      } else {
                        _selected.remove(candidate.merchantId);
                      }
                    });
                  },
          ),
        ],
      ),
    );
  }

  Widget _mapPreview() {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFDDEFF5), Color(0xFFBFD8E0)],
        ),
      ),
      child: Stack(
        children: [
          const Center(
            child: Text(
              'Buenos Aires',
              style: AppTextStyles.headingSm,
            ),
          ),
          Positioned(
            left: 10,
            right: 10,
            bottom: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${_candidates.length} FARMACIAS EN RADIO',
                style: AppTextStyles.bodyXs.copyWith(
                  color: AppColors.neutral700,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadCandidates() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ownerMerchant = await ref.read(ownerMerchantProvider.future);
      final merchant = ownerMerchant.primaryMerchant;
      _merchantRef = merchant?.id ?? '';
      final result = await ref
          .read(pharmacyDutyCommandServiceProvider)
          .getEligibleCandidates(
            dutyId: widget.dutyId,
          );
      _candidates = result.candidates;
      _maxCandidates = result.maxCandidatesPerRound;
      _zoneId = _candidates.isNotEmpty ? _candidates.first.zoneId : '';
      await PharmacyDutyFlowAnalytics.logCandidatesLoaded(
        zoneId: _zoneId,
        merchantRef: _merchantRef,
        candidateCount: _candidates.length,
      );
    } on PharmacyDutyCommandException catch (error) {
      _error = error.message;
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _createRound() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref
          .read(pharmacyDutyCommandServiceProvider)
          .createReassignmentRound(
            dutyId: widget.dutyId,
            candidateMerchantIds: _selected.toList(growable: false),
          );
      await PharmacyDutyFlowAnalytics.logRoundCreated(
        zoneId: _zoneId,
        merchantRef: _merchantRef,
        candidateCount: _selected.length,
      );
      if (!mounted) return;
      context.go(AppRoutes.ownerPharmacyDutyTrackingPath(widget.dutyId));
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
