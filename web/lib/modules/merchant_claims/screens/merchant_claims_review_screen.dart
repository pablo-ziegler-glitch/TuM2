import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/admin_semantic_assets.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../import_data/data/import_data_repository.dart';
import '../data/merchant_claims_admin_repository.dart';
import '../domain/merchant_claims_review_logic.dart';

const _defaultReviewStatuses = <MerchantClaimStatus>[
  MerchantClaimStatus.submitted,
  MerchantClaimStatus.underReview,
  MerchantClaimStatus.needsMoreInfo,
  MerchantClaimStatus.conflictDetected,
  MerchantClaimStatus.duplicateClaim,
];

class MerchantClaimsReviewScreen extends StatefulWidget {
  MerchantClaimsReviewScreen({
    super.key,
    this.initialClaimId,
    MerchantClaimsAdminDataSource? repository,
    Future<List<ZoneOption>> Function()? fetchZones,
  })  : repository = repository ?? MerchantClaimsAdminRepository(),
        fetchZones = fetchZones ?? ImportDataRepository().fetchAvailableZones;

  final String? initialClaimId;
  final MerchantClaimsAdminDataSource repository;
  final Future<List<ZoneOption>> Function() fetchZones;

  @override
  State<MerchantClaimsReviewScreen> createState() =>
      _MerchantClaimsReviewScreenState();
}

class _MerchantClaimsReviewScreenState
    extends State<MerchantClaimsReviewScreen> {
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'es');
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _resolveReasonController =
      TextEditingController();
  final TextEditingController _resolveNotesController = TextEditingController();
  final TextEditingController _revealReasonController = TextEditingController(
    text: 'manual_review',
  );

  final Set<MerchantClaimStatus> _selectedStatuses = {
    ..._defaultReviewStatuses,
  };
  final Set<SensitiveFieldKind> _revealFields = {
    SensitiveFieldKind.phone,
    SensitiveFieldKind.claimantDisplayName,
  };

  Timer? _searchDebounce;
  Timer? _revealTicker;

  List<ZoneOption> _zones = const [];
  List<MerchantClaimReviewItem> _claims = const [];
  MerchantClaimReviewCursor? _nextCursor;
  MerchantClaimsLocalFilters _localFilters = const MerchantClaimsLocalFilters();

  String? _selectedProvince;
  String? _selectedDepartment;
  String? _selectedZoneId;
  int _selectedLimit = 20;

  bool _loadingQueue = false;
  bool _loadingDetail = false;
  bool _runningAction = false;
  String? _queueError;
  String? _actionError;
  String? _selectedClaimId;

  MerchantClaimDetail? _detail;
  MerchantClaimStatus _resolveTargetStatus = MerchantClaimStatus.needsMoreInfo;
  Map<SensitiveFieldKind, String> _revealedValues = const {};
  DateTime? _revealExpiresAt;
  bool _detailStale = false;
  bool _showEvidenceMetadata = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChanged);
    unawaited(_bootstrap());
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _revealTicker?.cancel();
    _searchController.dispose();
    _resolveReasonController.dispose();
    _resolveNotesController.dispose();
    _revealReasonController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await _loadZones();
    await _loadQueue(reset: true);
    final claimId = widget.initialClaimId?.trim();
    if (claimId != null && claimId.isNotEmpty) {
      await _loadDetail(claimId, preserveRevealState: false);
    }
  }

  Future<void> _loadZones() async {
    try {
      final zones = await widget.fetchZones();
      if (!mounted) return;
      setState(() {
        _zones = zones;
        final provinces = _provinceOptions;
        if (_selectedProvince == null && provinces.isNotEmpty) {
          _selectedProvince = provinces.first;
        }
        final departments = _departmentOptions(_selectedProvince);
        if (_selectedDepartment == null && departments.isNotEmpty) {
          _selectedDepartment = departments.first;
        }
      });
    } catch (_) {
      if (!mounted) return;
      _showSnack(
        'No pudimos cargar las zonas disponibles del panel.',
        isError: true,
      );
    }
  }

  List<String> get _provinceOptions {
    final values = _zones
        .map((zone) => zone.provinceName.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);
    values.sort();
    return values;
  }

  List<String> _departmentOptions(String? province) {
    final normalized = province?.trim() ?? '';
    if (normalized.isEmpty) return const [];
    final values = _zones
        .where((zone) => zone.provinceName.trim() == normalized)
        .map((zone) => zone.departmentName.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);
    values.sort();
    return values;
  }

  List<ZoneOption> _cityOptions() {
    final province = _selectedProvince?.trim() ?? '';
    final department = _selectedDepartment?.trim() ?? '';
    if (province.isEmpty || department.isEmpty) return const [];
    final matches = _zones
        .where(
          (zone) =>
              zone.provinceName.trim() == province &&
              zone.departmentName.trim() == department,
        )
        .toList(growable: false);
    matches.sort(
      (left, right) => left.label.toLowerCase().compareTo(
            right.label.toLowerCase(),
          ),
    );
    return matches;
  }

  List<MerchantClaimReviewItem> get _visibleClaims =>
      applyMerchantClaimLocalFilters(items: _claims, filters: _localFilters);

  List<String> get _categoryOptions {
    final values = _claims
        .map((item) => item.categoryId?.trim() ?? '')
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);
    values.sort();
    return values;
  }

  Future<void> _loadQueue({required bool reset}) async {
    if (_loadingQueue) return;
    final province = _selectedProvince?.trim() ?? '';
    final department = _selectedDepartment?.trim() ?? '';
    if (province.isEmpty || department.isEmpty) {
      setState(() {
        _queueError =
            'Seleccioná provincia y departamento para consultar la cola.';
      });
      return;
    }
    if (_selectedStatuses.isEmpty) {
      setState(() => _queueError = 'Seleccioná al menos un estado.');
      return;
    }

    setState(() {
      _loadingQueue = true;
      _queueError = null;
    });

    try {
      final page = await widget.repository.listForReview(
        filters: MerchantClaimReviewFilters(
          provinceName: province,
          departmentName: department,
          zoneId: _selectedZoneId,
          statuses: _selectedStatuses.toList(growable: false),
          limit: _selectedLimit,
          cursor: reset ? null : _nextCursor,
        ),
      );
      if (!mounted) return;
      setState(() {
        _claims = reset ? page.claims : [..._claims, ...page.claims];
        _nextCursor = page.nextCursor;
        if (reset && _selectedClaimId != null) {
          final exists =
              _claims.any((item) => item.claimId == _selectedClaimId);
          if (!exists) {
            _selectedClaimId = null;
          }
        }
      });
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      setState(() {
        _queueError = error.message ?? 'No pudimos cargar la cola de claims.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _queueError = 'No pudimos cargar la cola de claims.';
      });
    } finally {
      if (mounted) setState(() => _loadingQueue = false);
    }
  }

  Future<void> _loadDetail(
    String claimId, {
    bool preserveRevealState = false,
  }) async {
    setState(() {
      _loadingDetail = true;
      _actionError = null;
      _selectedClaimId = claimId;
    });
    try {
      final detail = await widget.repository.getClaimDetail(claimId: claimId);
      if (!mounted) return;
      final wasStale = _detail != null &&
          _detail!.claimId == claimId &&
          isClaimDetailStale(
            openedUpdatedAtMillis: _detail!.updatedAtMillis,
            currentUpdatedAtMillis: detail.updatedAtMillis,
          );
      setState(() {
        _detail = detail;
        _detailStale = false;
        _resolveTargetStatus =
            detail.allowedStatuses.contains(detail.userVisibleStatus)
                ? detail.userVisibleStatus
                : (detail.allowedStatuses.isNotEmpty
                    ? detail.allowedStatuses.first
                    : MerchantClaimStatus.needsMoreInfo);
        _loadingDetail = false;
        _showEvidenceMetadata = false;
        if (!preserveRevealState || wasStale) {
          _revealedValues = const {};
          _revealExpiresAt = null;
        }
      });
      if (wasStale) {
        _showSnack(
          'El caso cambió mientras lo revisabas. Actualizamos el detalle.',
          isError: true,
        );
      }
      _syncDetailRoute(claimId);
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      setState(() {
        _actionError =
            error.message ?? 'No pudimos cargar el detalle del claim.';
        _detail = null;
        _loadingDetail = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _actionError = 'No pudimos cargar el detalle del claim.';
        _detail = null;
        _loadingDetail = false;
      });
    }
  }

  Future<void> _refreshDetail() async {
    final claimId = _selectedClaimId;
    if (claimId == null) return;
    await _loadDetail(claimId, preserveRevealState: false);
  }

  Future<void> _runEvaluate() async {
    final detail = _detail;
    if (detail == null ||
        _runningAction ||
        !detail.capabilities.canEvaluateClaim) {
      return;
    }
    setState(() {
      _runningAction = true;
      _actionError = null;
    });
    try {
      final result = await widget.repository.evaluateClaim(
        claimId: detail.claimId,
        expectedUpdatedAtMillis: detail.updatedAtMillis,
      );
      if (!mounted) return;
      _showSnack('Claim reevaluado: ${result.claimStatus.label}.');
      await _loadQueue(reset: true);
      await _loadDetail(detail.claimId, preserveRevealState: false);
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      await _handleActionError(error);
    } catch (_) {
      if (!mounted) return;
      _setActionError('No pudimos reevaluar el claim.');
    } finally {
      if (mounted) setState(() => _runningAction = false);
    }
  }

  Future<void> _runResolve() async {
    final detail = _detail;
    if (detail == null || _runningAction) return;
    if (!canResolveClaimStatus(detail, _resolveTargetStatus)) {
      _setActionError('Tu sesión no puede aplicar esa resolución.');
      return;
    }
    final reason = _resolveReasonController.text.trim();
    if (shouldRequireReasonCode(_resolveTargetStatus) && reason.isEmpty) {
      _setActionError('El motivo es obligatorio para esta resolución.');
      return;
    }

    setState(() {
      _runningAction = true;
      _actionError = null;
    });
    try {
      await widget.repository.resolveClaim(
        claimId: detail.claimId,
        targetStatus: _resolveTargetStatus,
        reviewReasonCode: reason,
        reviewNotes: _resolveNotesController.text.trim(),
        expectedUpdatedAtMillis: detail.updatedAtMillis,
      );
      if (!mounted) return;
      _showSnack('Claim resuelto: ${_resolveTargetStatus.label}.');
      await _loadQueue(reset: true);
      await _loadDetail(detail.claimId, preserveRevealState: false);
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      await _handleActionError(error);
    } catch (_) {
      if (!mounted) return;
      _setActionError('No pudimos resolver el claim.');
    } finally {
      if (mounted) setState(() => _runningAction = false);
    }
  }

  Future<void> _runReveal() async {
    final detail = _detail;
    if (detail == null || _runningAction || !detail.canRevealSensitive) return;
    if (_revealFields.isEmpty) {
      _setActionError('Seleccioná al menos un campo para revelar.');
      return;
    }
    final reason = _revealReasonController.text.trim();
    if (reason.isEmpty) {
      _setActionError('El motivo de reveal es obligatorio.');
      return;
    }

    setState(() {
      _runningAction = true;
      _actionError = null;
    });
    try {
      final result = await widget.repository.revealSensitiveData(
        claimId: detail.claimId,
        reasonCode: reason,
        fields: _revealFields.toList(growable: false),
        expectedUpdatedAtMillis: detail.updatedAtMillis,
      );
      if (!mounted) return;
      _revealTicker?.cancel();
      setState(() {
        _revealedValues = result.revealed;
        _revealExpiresAt =
            DateTime.fromMillisecondsSinceEpoch(result.expiresAtMillis);
      });
      _revealTicker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        final expiresAt = _revealExpiresAt;
        if (expiresAt == null || DateTime.now().isBefore(expiresAt)) {
          setState(() {});
          return;
        }
        _revealTicker?.cancel();
        setState(() {
          _revealedValues = const {};
          _revealExpiresAt = null;
        });
      });
      _showSnack('Reveal temporal auditado aplicado.');
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      await _handleActionError(error);
    } catch (_) {
      if (!mounted) return;
      _setActionError('No pudimos revelar los datos sensibles.');
    } finally {
      if (mounted) setState(() => _runningAction = false);
    }
  }

  Future<void> _handleActionError(FirebaseFunctionsException error) async {
    final details = error.details;
    if (details is Map && details['code'] == 'stale_claim') {
      setState(() {
        _detailStale = true;
        _actionError =
            'El caso cambió mientras lo revisabas. Actualizá antes de decidir.';
      });
      await _refreshDetail();
      return;
    }
    _setActionError(error.message ?? 'No pudimos completar la operación.');
  }

  void _setActionError(String message) {
    setState(() => _actionError = message);
    _showSnack(message, isError: true);
  }

  void _toggleStatus(MerchantClaimStatus status, bool enabled) {
    if (!enabled && _selectedStatuses.length == 1) {
      _showSnack('Debe quedar al menos un estado activo.', isError: true);
      return;
    }
    setState(() {
      if (enabled) {
        _selectedStatuses.add(status);
      } else {
        _selectedStatuses.remove(status);
      }
    });
  }

  void _toggleRevealField(SensitiveFieldKind field, bool enabled) {
    setState(() {
      if (enabled) {
        _revealFields.add(field);
      } else {
        _revealFields.remove(field);
      }
    });
  }

  void _handleSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 220), () {
      if (!mounted) return;
      setState(() {
        _localFilters = _localFilters.copyWith(query: _searchController.text);
      });
    });
  }

  void _syncDetailRoute(String claimId) {
    final route = '/claims/$claimId';
    if (GoRouterState.of(context).matchedLocation != route) {
      context.go(route);
    }
  }

  void _closeDetail() {
    setState(() {
      _selectedClaimId = null;
      _detail = null;
      _actionError = null;
      _detailStale = false;
      _revealedValues = const {};
      _revealExpiresAt = null;
    });
    context.go('/claims');
  }

  String _formatDate(int? millis) {
    if (millis == null || millis <= 0) return '-';
    return _dateFormat.format(DateTime.fromMillisecondsSinceEpoch(millis));
  }

  String _formatRemainingReveal() {
    final expiresAt = _revealExpiresAt;
    if (expiresAt == null) return '-';
    final remaining = expiresAt.difference(DateTime.now()).inSeconds;
    if (remaining <= 0) return 'expirado';
    final minutes = remaining ~/ 60;
    final seconds = remaining % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: isError ? AppColors.errorFg : AppColors.neutral900,
        content: Text(message),
      ),
    );
  }

  AdminBadgeKey _claimBadgeKey(MerchantClaimStatus status) {
    return switch (status) {
      MerchantClaimStatus.draft => AdminBadgeKey.claimDraft,
      MerchantClaimStatus.submitted => AdminBadgeKey.claimSubmitted,
      MerchantClaimStatus.underReview => AdminBadgeKey.claimUnderReview,
      MerchantClaimStatus.needsMoreInfo => AdminBadgeKey.claimNeedsMoreInfo,
      MerchantClaimStatus.approved => AdminBadgeKey.claimApproved,
      MerchantClaimStatus.rejected => AdminBadgeKey.claimRejected,
      MerchantClaimStatus.duplicateClaim => AdminBadgeKey.claimDuplicate,
      MerchantClaimStatus.conflictDetected => AdminBadgeKey.claimConflict,
    };
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: detail == null
            ? _buildQueueWorkspace()
            : _buildDetailWorkspace(detail),
      ),
    );
  }

  Widget _buildQueueWorkspace() {
    final visibleClaims = _visibleClaims;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 12),
        _buildBackendFiltersCard(),
        const SizedBox(height: 12),
        _buildLocalFiltersCard(),
        const SizedBox(height: 12),
        Expanded(
          child: _PanelCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Cola de claims',
                      style: AppTextStyles.headingSm.copyWith(
                        fontFamily: 'Manrope',
                      ),
                    ),
                    const SizedBox(width: 8),
                    _MetricPill(
                      label: 'Lote cargado',
                      value: '${_claims.length}',
                    ),
                    const SizedBox(width: 8),
                    _MetricPill(
                      label: 'Visible',
                      value: '${visibleClaims.length}',
                    ),
                    const Spacer(),
                    if (_loadingQueue)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
                if (_queueError != null) ...[
                  const SizedBox(height: 12),
                  _InlineBanner(
                    color: AppColors.errorBg,
                    borderColor: AppColors.errorFg.withValues(alpha: 0.2),
                    child: Text(
                      _queueError!,
                      style: AppTextStyles.bodySm.copyWith(
                        color: AppColors.errorFg,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Expanded(
                  child: visibleClaims.isEmpty
                      ? Center(
                          child: Text(
                            _loadingQueue
                                ? 'Cargando cola de claims...'
                                : 'No hay claims para los filtros activos.',
                            style: AppTextStyles.bodySm,
                          ),
                        )
                      : ListView.separated(
                          itemCount: visibleClaims.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final item = visibleClaims[index];
                            return ListTile(
                              title: Text(
                                item.merchantName ?? item.merchantId,
                                style: AppTextStyles.bodySm.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                '${item.claimId} · ${_zoneLabel(item.zoneId)} · ${item.categoryId ?? '-'}',
                                style: AppTextStyles.bodyXs,
                              ),
                              trailing: Wrap(
                                spacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  _StatusBadge(
                                    badgeKey: _claimBadgeKey(
                                      item.claimStatus,
                                    ),
                                    label: item.claimStatus.label,
                                  ),
                                  if (item.hasConflict)
                                    const Icon(
                                      Icons.warning_amber_rounded,
                                      color: AppColors.errorFg,
                                      size: 18,
                                    ),
                                  Text(
                                    _formatDate(item.createdAtMillis),
                                    style: AppTextStyles.bodyXs,
                                  ),
                                  TextButton(
                                    onPressed: () => _loadDetail(item.claimId),
                                    child: const Text('Abrir'),
                                  ),
                                ],
                              ),
                              onTap: () => _loadDetail(item.claimId),
                            );
                          },
                        ),
                ),
                if (_nextCursor != null) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      onPressed:
                          _loadingQueue ? null : () => _loadQueue(reset: false),
                      icon: const Icon(Icons.expand_more),
                      label: const Text('Cargar más'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailWorkspace(MerchantClaimDetail detail) {
    final canReveal = detail.canRevealSensitive && !_detailStale;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            TextButton.icon(
              onPressed: _closeDetail,
              icon: const Icon(Icons.arrow_back),
              label: const Text('Volver a la cola'),
            ),
            const SizedBox(width: 8),
            Text(
              detail.claimId,
              style: AppTextStyles.headingMd.copyWith(fontFamily: 'Manrope'),
            ),
            const SizedBox(width: 8),
            _StatusBadge(
              badgeKey: _claimBadgeKey(detail.userVisibleStatus),
              label: detail.userVisibleStatus.label,
            ),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: _loadingDetail ? null : _refreshDetail,
              icon: const Icon(Icons.refresh),
              label: const Text('Actualizar'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_detailStale || _actionError != null)
          _InlineBanner(
            color: _detailStale ? AppColors.warningBg : AppColors.errorBg,
            borderColor: _detailStale
                ? AppColors.warningFg.withValues(alpha: 0.2)
                : AppColors.errorFg.withValues(alpha: 0.2),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _actionError ??
                        'Este caso cambió mientras lo estabas revisando.',
                    style: AppTextStyles.bodySm.copyWith(
                      color: _detailStale
                          ? AppColors.warningFg
                          : AppColors.errorFg,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: _refreshDetail,
                  child: const Text('Actualizar'),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildSummaryCard(detail),
                      const SizedBox(height: 12),
                      _buildMerchantCard(detail),
                      const SizedBox(height: 12),
                      _buildApplicantCard(detail),
                      const SizedBox(height: 12),
                      _buildEvidenceCard(detail),
                      const SizedBox(height: 12),
                      _buildAutoValidationCard(detail),
                      const SizedBox(height: 12),
                      _buildTimelineCard(detail),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 360,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildActionsCard(detail),
                      const SizedBox(height: 12),
                      _buildRevealCard(detail, enabled: canReveal),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Claims Review',
                style: AppTextStyles.bodyXs.copyWith(
                  color: AppColors.primary600,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Triage operativo de claims',
                style: AppTextStyles.headingMd.copyWith(fontFamily: 'Manrope'),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          onPressed: _loadingQueue ? null : () => _loadQueue(reset: true),
          icon: const Icon(Icons.refresh),
          label: const Text('Actualizar cola'),
        ),
      ],
    );
  }

  Widget _buildBackendFiltersCard() {
    final cities = _cityOptions();
    return _PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Scope Firestore',
            style: AppTextStyles.labelMd.copyWith(fontFamily: 'Manrope'),
          ),
          const SizedBox(height: 4),
          Text(
            'La consulta siempre baja una página acotada por provincia, departamento, zoneId y claimStatus.',
            style: AppTextStyles.bodyXs.copyWith(color: AppColors.neutral600),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _DropdownField<String>(
                width: 220,
                label: 'Provincia',
                value: _selectedProvince,
                items: _provinceOptions,
                onChanged: (value) {
                  setState(() {
                    _selectedProvince = value;
                    _selectedDepartment = _departmentOptions(value).firstOrNull;
                    _selectedZoneId = null;
                  });
                },
              ),
              _DropdownField<String>(
                width: 220,
                label: 'Departamento',
                value: _selectedDepartment,
                items: _departmentOptions(_selectedProvince),
                onChanged: (value) {
                  setState(() {
                    _selectedDepartment = value;
                    _selectedZoneId = null;
                  });
                },
              ),
              _DropdownField<String>(
                width: 260,
                label: 'Ciudad / ZoneId',
                value: _selectedZoneId,
                allowEmpty: true,
                emptyLabel: 'Todo el departamento',
                items:
                    cities.map((zone) => zone.zoneId).toList(growable: false),
                labelBuilder: (value) => _zoneLabel(value),
                onChanged: (value) => setState(() => _selectedZoneId = value),
              ),
              _DropdownField<int>(
                width: 120,
                label: 'Límite',
                value: _selectedLimit,
                items: const [10, 20, 30, 50],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _selectedLimit = value);
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _defaultReviewStatuses
                .map(
                  (status) => FilterChip(
                    selected: _selectedStatuses.contains(status),
                    onSelected: (enabled) => _toggleStatus(status, enabled),
                    label: Text(status.label),
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ),
    );
  }

  Widget _buildLocalFiltersCard() {
    return _PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Refinamiento local del lote cargado',
            style: AppTextStyles.labelMd.copyWith(fontFamily: 'Manrope'),
          ),
          const SizedBox(height: 4),
          Text(
            'No dispara nuevas lecturas: filtra y ordena sólo la página ya traída de Firestore.',
            style: AppTextStyles.bodyXs.copyWith(color: AppColors.neutral600),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    labelText: 'Buscar por claimId, comercio o zoneId',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _DropdownField<String>(
                width: 180,
                label: 'Categoría',
                value: _localFilters.categoryId,
                allowEmpty: true,
                emptyLabel: 'Todas',
                items: _categoryOptions,
                onChanged: (value) {
                  setState(() {
                    _localFilters = _localFilters.copyWith(
                      categoryId: value,
                      clearCategory: value == null,
                    );
                  });
                },
              ),
              const SizedBox(width: 12),
              _DropdownField<MerchantClaimsSortOption>(
                width: 200,
                label: 'Orden',
                value: _localFilters.sort,
                items: MerchantClaimsSortOption.values,
                labelBuilder: (value) => switch (value) {
                  MerchantClaimsSortOption.newestFirst => 'Más recientes',
                  MerchantClaimsSortOption.oldestPendingFirst =>
                    'Más antiguos sin resolver',
                  MerchantClaimsSortOption.conflictFirst => 'Conflicto primero',
                  MerchantClaimsSortOption.pendingActionFirst =>
                    'Pendientes primero',
                  MerchantClaimsSortOption.riskFirst => 'Riesgo primero',
                },
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _localFilters = _localFilters.copyWith(sort: value);
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SwitchChip(
                label: 'Conflicto',
                value: _localFilters.conflictOnly,
                onChanged: (value) => setState(() {
                  _localFilters = _localFilters.copyWith(conflictOnly: value);
                }),
              ),
              _SwitchChip(
                label: 'Falta info',
                value: _localFilters.missingInfoOnly,
                onChanged: (value) => setState(() {
                  _localFilters =
                      _localFilters.copyWith(missingInfoOnly: value);
                }),
              ),
              _SwitchChip(
                label: 'Owner existente',
                value: _localFilters.existingOwnerOnly,
                onChanged: (value) => setState(() {
                  _localFilters =
                      _localFilters.copyWith(existingOwnerOnly: value);
                }),
              ),
              _SwitchChip(
                label: 'Duplicado',
                value: _localFilters.duplicateOnly,
                onChanged: (value) => setState(() {
                  _localFilters = _localFilters.copyWith(duplicateOnly: value);
                }),
              ),
              _SwitchChip(
                label: 'Observado',
                value: _localFilters.observedOnly,
                onChanged: (value) => setState(() {
                  _localFilters = _localFilters.copyWith(observedOnly: value);
                }),
              ),
              _SwitchChip(
                label: 'Pendiente',
                value: _localFilters.pendingOnly,
                onChanged: (value) => setState(() {
                  _localFilters = _localFilters.copyWith(pendingOnly: value);
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(MerchantClaimDetail detail) {
    return _DetailSection(
      title: 'Resumen del caso',
      child: Column(
        children: [
          _kv('Claim ID', detail.claimId),
          _kv('Estado interno', detail.claimStatus.apiValue),
          _kv('Estado visible', detail.userVisibleStatus.label),
          _kv('Zona', _zoneLabel(detail.zoneId ?? '-')),
          _kv('Categoría', detail.categoryId ?? '-'),
          _kv('Policy versión', detail.evidencePolicyVersion ?? '-'),
          _kv('Policy categoría', detail.evidencePolicyCategoryId ?? '-'),
          _kv('Policy strictness', detail.evidencePolicyStrictnessLevel ?? '-'),
          _kv('Flujo interno', detail.internalWorkflowStatus ?? '-'),
          _kv('Creado', _formatDate(detail.createdAtMillis)),
          _kv('Enviado', _formatDate(detail.submittedAtMillis)),
          _kv('Actualizado', _formatDate(detail.updatedAtMillis)),
        ],
      ),
    );
  }

  Widget _buildMerchantCard(MerchantClaimDetail detail) {
    return _DetailSection(
      title: 'Comercio',
      child: Column(
        children: [
          _kv('Nombre', detail.merchantName ?? detail.merchantId),
          _kv('Dirección', detail.merchantAddress ?? '-'),
          _kv('Estado comercio', detail.merchantStatus ?? '-'),
          _kv('Ownership', detail.merchantOwnershipStatus ?? '-'),
          _kv('Owner actual', detail.existingOwnerMasked ?? '-'),
          _kv('Rol declarado', detail.declaredRole ?? '-'),
        ],
      ),
    );
  }

  Widget _buildApplicantCard(MerchantClaimDetail detail) {
    return _DetailSection(
      title: 'Solicitante',
      child: Column(
        children: [
          _kv('Usuario', detail.userIdMasked),
          _kv('Email auth', detail.authenticatedEmailMasked ?? '-'),
          _kv(
              'Teléfono',
              _revealedValues[SensitiveFieldKind.phone] ??
                  detail.phoneMasked ??
                  '-'),
          _kv(
            'Nombre',
            _revealedValues[SensitiveFieldKind.claimantDisplayName] ??
                detail.claimantDisplayNameMasked ??
                '-',
          ),
          _kv(
            'Nota',
            _revealedValues[SensitiveFieldKind.claimantNote] ??
                detail.claimantNoteMasked ??
                '-',
          ),
        ],
      ),
    );
  }

  Widget _buildEvidenceCard(MerchantClaimDetail detail) {
    return _DetailSection(
      title: 'Evidencia',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _kv('Fachada', detail.storefrontPhotoUploaded ? 'Sí' : 'No'),
          _kv(
            'Documento titularidad',
            detail.ownershipDocumentUploaded ? 'Sí' : 'No',
          ),
          _kv(
            'Tipos faltantes',
            detail.missingEvidenceTypes.isEmpty
                ? '-'
                : detail.missingEvidenceTypes.join(', '),
          ),
          _kv(
            'Suficiencia',
            detail.sufficiencyLevel ?? '-',
          ),
          _kv(
            'Cumple mínimos',
            detail.requiredEvidenceSatisfied ? 'Sí' : 'No',
          ),
          _kv(
            'Visual primaria detectada',
            detail.primaryVisualEvidenceType ?? '-',
          ),
          _kv(
            'Tipos de vínculo',
            detail.relationshipEvidenceTypes.isEmpty
                ? '-'
                : detail.relationshipEvidenceTypes.join(', '),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () {
              setState(() => _showEvidenceMetadata = !_showEvidenceMetadata);
            },
            icon: Icon(
              _showEvidenceMetadata ? Icons.expand_less : Icons.expand_more,
            ),
            label: Text(
              _showEvidenceMetadata
                  ? 'Ocultar metadata'
                  : 'Cargar metadata de evidencia',
            ),
          ),
          if (_showEvidenceMetadata) ...[
            const SizedBox(height: 8),
            if (detail.evidenceFiles.isEmpty)
              Text(
                'No hay archivos metadata para este claim.',
                style: AppTextStyles.bodyXs,
              )
            else
              ...detail.evidenceFiles.map(
                (file) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '${file.kind} · ${file.originalFileName ?? file.id} · ${file.contentType} · ${file.sizeBytes} bytes',
                    style: AppTextStyles.bodyXs,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildAutoValidationCard(MerchantClaimDetail detail) {
    return _DetailSection(
      title: 'Validación automática',
      child: Column(
        children: [
          _kv('Motivo principal', detail.autoValidationReasonCode ?? '-'),
          _kv(
            'Motivos observados',
            detail.autoValidationReasons.isEmpty
                ? '-'
                : detail.autoValidationReasons.join(', '),
          ),
          _kv('Conflicto', detail.hasConflict ? 'Sí' : 'No'),
          _kv('Duplicado', detail.hasDuplicate ? 'Sí' : 'No'),
          _kv('Riesgo', detail.riskPriority ?? '-'),
          _kv(
            'Razones de revisión manual',
            detail.manualReviewReasons.isEmpty
                ? '-'
                : detail.manualReviewReasons.join(', '),
          ),
          _kv(
            'Risk hints',
            detail.riskHints.isEmpty ? '-' : detail.riskHints.join(', '),
          ),
          _kv(
            'Flags de riesgo',
            detail.riskFlags.isEmpty ? '-' : detail.riskFlags.join(', '),
          ),
          _kv(
            'Auto-validado en',
            _formatDate(detail.autoValidationCompletedAtMillis),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineCard(MerchantClaimDetail detail) {
    return _DetailSection(
      title: 'Timeline',
      child: Column(
        children: detail.timeline
            .map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.circle,
                        size: 10, color: AppColors.primary500),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.label,
                            style: AppTextStyles.bodySm.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '${_formatDate(item.atMillis)} · ${item.actorMasked ?? 'sistema'}',
                            style: AppTextStyles.bodyXs.copyWith(
                              color: AppColors.neutral600,
                            ),
                          ),
                          if ((item.detail ?? '').isNotEmpty)
                            Text(
                              item.detail!,
                              style: AppTextStyles.bodyXs,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }

  Widget _buildActionsCard(MerchantClaimDetail detail) {
    return _PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Decisiones manuales',
            style: AppTextStyles.labelMd.copyWith(fontFamily: 'Manrope'),
          ),
          const SizedBox(height: 8),
          Text(
            'El backend valida token de concurrencia contra `updatedAt` antes de mutar el claim.',
            style: AppTextStyles.bodyXs.copyWith(color: AppColors.neutral600),
          ),
          const SizedBox(height: 12),
          _DropdownField<MerchantClaimStatus>(
            width: double.infinity,
            label: 'Resolución',
            value: _resolveTargetStatus,
            items: detail.allowedStatuses,
            labelBuilder: (value) => value.label,
            onChanged: (value) {
              if (value == null) return;
              setState(() => _resolveTargetStatus = value);
            },
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _resolveReasonController,
            decoration: const InputDecoration(
              labelText: 'Motivo',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _resolveNotesController,
            minLines: 3,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Observaciones internas',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _runningAction ||
                          !detail.capabilities.canEvaluateClaim ||
                          _detailStale
                      ? null
                      : _runEvaluate,
                  icon: const Icon(Icons.bolt),
                  label: const Text('Reevaluar'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _runningAction ||
                          !canResolveClaimStatus(
                              detail, _resolveTargetStatus) ||
                          _detailStale
                      ? null
                      : _runResolve,
                  icon: const Icon(Icons.task_alt),
                  label: const Text('Aplicar'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Estados permitidos por capability: ${detail.allowedStatuses.map((item) => item.label).join(', ')}',
            style: AppTextStyles.bodyXs.copyWith(color: AppColors.neutral600),
          ),
        ],
      ),
    );
  }

  Widget _buildRevealCard(
    MerchantClaimDetail detail, {
    required bool enabled,
  }) {
    return _PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Reveal sensible',
            style: AppTextStyles.labelMd.copyWith(fontFamily: 'Manrope'),
          ),
          const SizedBox(height: 8),
          Text(
            enabled
                ? 'Masking por defecto. Reveal temporal y auditado.'
                : 'Tu sesión no puede revelar sensibles o el detalle quedó stale.',
            style: AppTextStyles.bodyXs.copyWith(color: AppColors.neutral600),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: SensitiveFieldKind.values
                .map(
                  (field) => FilterChip(
                    selected: _revealFields.contains(field),
                    onSelected: enabled
                        ? (value) => _toggleRevealField(field, value)
                        : null,
                    label: Text(_sensitiveLabel(field)),
                  ),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _revealReasonController,
            enabled: enabled,
            decoration: const InputDecoration(
              labelText: 'Motivo de reveal',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _runningAction || !enabled ? null : _runReveal,
            icon: const Icon(Icons.visibility),
            label: const Text('Revelar'),
          ),
          if (_revealExpiresAt != null) ...[
            const SizedBox(height: 8),
            Text(
              'Expira en ${_formatRemainingReveal()}',
              style: AppTextStyles.bodyXs.copyWith(color: AppColors.neutral700),
            ),
          ],
        ],
      ),
    );
  }

  String _sensitiveLabel(SensitiveFieldKind field) {
    return switch (field) {
      SensitiveFieldKind.phone => 'Teléfono',
      SensitiveFieldKind.claimantDisplayName => 'Nombre',
      SensitiveFieldKind.claimantNote => 'Nota',
    };
  }

  String _zoneLabel(String zoneId) {
    if (zoneId.trim().isEmpty) return '-';
    for (final zone in _zones) {
      if (zone.zoneId == zoneId) return zone.label;
    }
    return zoneId;
  }

  Widget _kv(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 170,
            child: Text(
              label,
              style: AppTextStyles.bodyXs.copyWith(
                color: AppColors.neutral600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.bodySm,
            ),
          ),
        ],
      ),
    );
  }
}

class _PanelCard extends StatelessWidget {
  const _PanelCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.neutral200),
      ),
      child: child,
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTextStyles.labelMd.copyWith(fontFamily: 'Manrope'),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _InlineBanner extends StatelessWidget {
  const _InlineBanner({
    required this.color,
    required this.borderColor,
    required this.child,
  });

  final Color color;
  final Color borderColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: child,
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.badgeKey,
    required this.label,
  });

  final AdminBadgeKey badgeKey;
  final String label;

  @override
  Widget build(BuildContext context) {
    return AdminSemanticBadge(
      badgeKey: badgeKey,
      label: label,
      compact: true,
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.neutral100,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $value',
        style: AppTextStyles.bodyXs.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _SwitchChip extends StatelessWidget {
  const _SwitchChip({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      selected: value,
      onSelected: onChanged,
      label: Text(label),
    );
  }
}

class _DropdownField<T> extends StatelessWidget {
  const _DropdownField({
    required this.width,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.labelBuilder,
    this.allowEmpty = false,
    this.emptyLabel = 'Todos',
  });

  final double width;
  final String label;
  final T? value;
  final List<T> items;
  final ValueChanged<T?> onChanged;
  final String Function(T value)? labelBuilder;
  final bool allowEmpty;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: DropdownButtonFormField<T>(
        isExpanded: true,
        initialValue: value,
        items: [
          if (allowEmpty)
            DropdownMenuItem<T>(
              value: null,
              child: Text(emptyLabel),
            ),
          ...items.map(
            (item) => DropdownMenuItem<T>(
              value: item,
              child: Text(labelBuilder?.call(item) ?? item.toString()),
            ),
          ),
        ],
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
