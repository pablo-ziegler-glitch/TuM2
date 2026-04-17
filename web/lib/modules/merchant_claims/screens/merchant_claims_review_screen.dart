import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../import_data/data/import_data_repository.dart';
import '../data/merchant_claims_admin_repository.dart';

const _defaultReviewStatuses = <MerchantClaimStatus>[
  MerchantClaimStatus.submitted,
  MerchantClaimStatus.underReview,
  MerchantClaimStatus.needsMoreInfo,
  MerchantClaimStatus.conflictDetected,
  MerchantClaimStatus.duplicateClaim,
];

const _resolveStatuses = <MerchantClaimStatus>[
  MerchantClaimStatus.approved,
  MerchantClaimStatus.rejected,
  MerchantClaimStatus.needsMoreInfo,
  MerchantClaimStatus.conflictDetected,
  MerchantClaimStatus.duplicateClaim,
];

class MerchantClaimsReviewScreen extends StatefulWidget {
  const MerchantClaimsReviewScreen({super.key});

  @override
  State<MerchantClaimsReviewScreen> createState() =>
      _MerchantClaimsReviewScreenState();
}

class _MerchantClaimsReviewScreenState
    extends State<MerchantClaimsReviewScreen> {
  final MerchantClaimsAdminRepository _claimsRepository =
      MerchantClaimsAdminRepository();
  final ImportDataRepository _zonesRepository = ImportDataRepository();
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'es');

  final TextEditingController _zoneIdController = TextEditingController();
  final TextEditingController _resolveReasonController =
      TextEditingController();
  final TextEditingController _resolveNotesController = TextEditingController();
  final TextEditingController _revealReasonController = TextEditingController(
    text: 'manual_review',
  );

  final Set<MerchantClaimStatus> _selectedStatuses = {
    ..._defaultReviewStatuses,
  };
  final Set<SensitiveFieldKind> _revealFields = {...SensitiveFieldKind.values};

  List<ZoneOption> _zones = const [];
  bool _loadingZones = true;

  int _selectedLimit = 20;
  bool _loadingQueue = false;
  String? _queueError;
  List<MerchantClaimReviewItem> _claims = const [];
  MerchantClaimReviewCursor? _nextCursor;

  String? _selectedClaimId;
  bool _loadingDetail = false;
  String? _detailError;
  MerchantClaimDetail? _detail;

  bool _runningAction = false;
  MerchantClaimStatus _resolveTargetStatus = MerchantClaimStatus.needsMoreInfo;

  Map<SensitiveFieldKind, String> _revealedValues = const {};
  DateTime? _revealExpiresAt;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _loadZones();
    await _loadQueue(reset: true);
  }

  @override
  void dispose() {
    _zoneIdController.dispose();
    _resolveReasonController.dispose();
    _resolveNotesController.dispose();
    _revealReasonController.dispose();
    super.dispose();
  }

  Future<void> _loadZones() async {
    setState(() => _loadingZones = true);
    try {
      final zones = await _zonesRepository.fetchAvailableZones();
      if (!mounted) return;
      setState(() {
        _zones = zones;
        if (_zoneIdController.text.trim().isEmpty && zones.isNotEmpty) {
          _zoneIdController.text = zones.first.zoneId;
        }
      });
    } catch (error) {
      if (!mounted) return;
      _showSnack(
        'No pudimos cargar zonas. Podes escribir zoneId manualmente.',
        isError: true,
      );
      setState(() => _zones = const []);
    } finally {
      if (mounted) setState(() => _loadingZones = false);
    }
  }

  Future<void> _loadQueue({required bool reset}) async {
    if (_loadingQueue) return;
    final zoneId = _zoneIdController.text.trim();
    if (zoneId.isEmpty) {
      setState(() {
        _queueError = 'ZoneId es obligatorio para consultar la cola.';
        if (reset) {
          _claims = const [];
          _nextCursor = null;
        }
      });
      return;
    }
    if (_selectedStatuses.isEmpty) {
      setState(() {
        _queueError = 'Selecciona al menos un estado.';
      });
      return;
    }

    setState(() {
      _loadingQueue = true;
      _queueError = null;
    });

    try {
      final page = await _claimsRepository.listForReview(
        filters: MerchantClaimReviewFilters(
          zoneId: zoneId,
          statuses: _selectedStatuses.toList(growable: false),
          limit: _selectedLimit,
          cursor: reset ? null : _nextCursor,
        ),
      );

      if (!mounted) return;

      String? nextSelectedId = _selectedClaimId;
      if (reset) {
        final exists = page.claims.any(
          (item) => item.claimId == nextSelectedId,
        );
        if (!exists) {
          nextSelectedId =
              page.claims.isNotEmpty ? page.claims.first.claimId : null;
        }
      }

      setState(() {
        _claims = reset
            ? page.claims
            : <MerchantClaimReviewItem>[..._claims, ...page.claims];
        _nextCursor = page.nextCursor;
        _selectedClaimId = nextSelectedId;
        if (nextSelectedId == null) {
          _detail = null;
          _detailError = null;
          _revealedValues = const {};
          _revealExpiresAt = null;
        }
      });

      if (reset && nextSelectedId != null) {
        await _loadDetail(nextSelectedId, silent: true);
      }
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      setState(() {
        _queueError = error.message ?? 'No pudimos cargar la cola de claims.';
        if (reset) {
          _claims = const [];
          _nextCursor = null;
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _queueError = 'No pudimos cargar la cola de claims.';
        if (reset) {
          _claims = const [];
          _nextCursor = null;
        }
      });
    } finally {
      if (mounted) setState(() => _loadingQueue = false);
    }
  }

  Future<void> _loadDetail(String claimId, {bool silent = false}) async {
    setState(() {
      _selectedClaimId = claimId;
      _loadingDetail = true;
      if (!silent) _detailError = null;
    });
    try {
      final detail = await _claimsRepository.getClaimDetail(claimId: claimId);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _detailError = null;
        _loadingDetail = false;
        _resolveTargetStatus = _resolveStatuses.contains(detail.claimStatus)
            ? detail.claimStatus
            : MerchantClaimStatus.needsMoreInfo;
        _resolveReasonController.clear();
        _resolveNotesController.clear();
        _revealedValues = const {};
        _revealExpiresAt = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _detailError = 'No pudimos cargar el detalle del claim.';
        _detail = null;
        _loadingDetail = false;
      });
    }
  }

  Future<void> _runEvaluate() async {
    final claimId = _selectedClaimId;
    if (claimId == null || _runningAction) return;
    setState(() => _runningAction = true);
    try {
      final result = await _claimsRepository.evaluateClaim(claimId: claimId);
      if (!mounted) return;
      _showSnack('Claim reevaluado: ${result.claimStatus.label}.');
      setState(() => _selectedClaimId = claimId);
      await _loadQueue(reset: true);
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      _showSnack(
        error.message ?? 'No pudimos reevaluar el claim.',
        isError: true,
      );
    } catch (_) {
      if (!mounted) return;
      _showSnack('No pudimos reevaluar el claim.', isError: true);
    } finally {
      if (mounted) setState(() => _runningAction = false);
    }
  }

  Future<void> _runResolve() async {
    final claimId = _selectedClaimId;
    if (claimId == null || _runningAction) return;
    setState(() => _runningAction = true);
    try {
      final result = await _claimsRepository.resolveClaim(
        claimId: claimId,
        targetStatus: _resolveTargetStatus,
        reviewReasonCode: _resolveReasonController.text.trim(),
        reviewNotes: _resolveNotesController.text.trim(),
      );
      if (!mounted) return;
      _showSnack('Claim resuelto: ${result.claimStatus.label}.');
      setState(() => _selectedClaimId = claimId);
      await _loadQueue(reset: true);
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      _showSnack(
        error.message ?? 'No pudimos resolver el claim.',
        isError: true,
      );
    } catch (_) {
      if (!mounted) return;
      _showSnack('No pudimos resolver el claim.', isError: true);
    } finally {
      if (mounted) setState(() => _runningAction = false);
    }
  }

  Future<void> _runReveal() async {
    final claimId = _selectedClaimId;
    if (claimId == null || _runningAction) return;
    if (_revealFields.isEmpty) {
      _showSnack('Selecciona al menos un campo para reveal.', isError: true);
      return;
    }
    final reason = _revealReasonController.text.trim();
    if (reason.isEmpty) {
      _showSnack('Reason code es obligatorio para reveal.', isError: true);
      return;
    }

    setState(() => _runningAction = true);
    try {
      final result = await _claimsRepository.revealSensitiveData(
        claimId: claimId,
        reasonCode: reason,
        fields: _revealFields.toList(growable: false),
      );
      if (!mounted) return;
      setState(() {
        _revealedValues = result.revealed;
        _revealExpiresAt = DateTime.fromMillisecondsSinceEpoch(
          result.expiresAtMillis,
        );
      });
      _showSnack('Reveal aplicado de forma temporal y auditada.');
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      _showSnack(
        error.message ?? 'No pudimos revelar datos sensibles.',
        isError: true,
      );
    } catch (_) {
      if (!mounted) return;
      _showSnack('No pudimos revelar datos sensibles.', isError: true);
    } finally {
      if (mounted) setState(() => _runningAction = false);
    }
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

  String _formatDate(int? millis) {
    if (millis == null || millis <= 0) return '-';
    return _dateFormat.format(DateTime.fromMillisecondsSinceEpoch(millis));
  }

  Color _statusBg(MerchantClaimStatus status) {
    return switch (status) {
      MerchantClaimStatus.approved => AppColors.successBg,
      MerchantClaimStatus.rejected => AppColors.errorBg,
      MerchantClaimStatus.needsMoreInfo => AppColors.warningBg,
      MerchantClaimStatus.conflictDetected => AppColors.errorBg,
      MerchantClaimStatus.duplicateClaim => AppColors.warningBg,
      MerchantClaimStatus.underReview => AppColors.infoBg,
      MerchantClaimStatus.submitted => AppColors.primary50,
      MerchantClaimStatus.draft => AppColors.neutral100,
    };
  }

  Color _statusFg(MerchantClaimStatus status) {
    return switch (status) {
      MerchantClaimStatus.approved => AppColors.successFg,
      MerchantClaimStatus.rejected => AppColors.errorFg,
      MerchantClaimStatus.needsMoreInfo => AppColors.warningFg,
      MerchantClaimStatus.conflictDetected => AppColors.errorFg,
      MerchantClaimStatus.duplicateClaim => AppColors.warningFg,
      MerchantClaimStatus.underReview => AppColors.primary600,
      MerchantClaimStatus.submitted => AppColors.primary700,
      MerchantClaimStatus.draft => AppColors.neutral700,
    };
  }

  void _showSnack(String message, {bool isError = false}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: isError ? AppColors.errorFg : AppColors.neutral900,
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 12),
            _buildFiltersCard(),
            const SizedBox(height: 12),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 1280) {
                    return Column(
                      children: [
                        Expanded(child: _buildQueuePanel()),
                        const SizedBox(height: 12),
                        Expanded(child: _buildDetailPanel()),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(flex: 5, child: _buildQueuePanel()),
                      const SizedBox(width: 12),
                      Expanded(flex: 4, child: _buildDetailPanel()),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Claims Review', style: AppTextStyles.headingMd),
            const SizedBox(height: 2),
            Text(
              'Queue manual de reclamos de titularidad (sin listeners globales).',
              style: AppTextStyles.bodySm,
            ),
          ],
        ),
        const Spacer(),
        OutlinedButton.icon(
          onPressed: _loadingQueue ? null : () => _loadQueue(reset: true),
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('Refresh'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.neutral700,
            side: const BorderSide(color: AppColors.neutral300),
            textStyle: AppTextStyles.labelSm,
          ),
        ),
      ],
    );
  }

  Widget _buildFiltersCard() {
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
          Row(
            children: [
              SizedBox(
                width: 260,
                child: TextField(
                  controller: _zoneIdController,
                  decoration: InputDecoration(
                    labelText: 'ZoneId',
                    hintText: 'ej: zone-1',
                    border: const OutlineInputBorder(),
                    isDense: true,
                    suffixIcon: _loadingZones
                        ? const Padding(
                            padding: EdgeInsets.all(10),
                            child: SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 120,
                child: DropdownMenu<int>(
                  initialSelection: _selectedLimit,
                  label: const Text('Limit'),
                  dropdownMenuEntries: const [10, 20, 30, 50]
                      .map(
                        (value) => DropdownMenuEntry<int>(
                            value: value, label: '$value'),
                      )
                      .toList(growable: false),
                  onSelected: (value) {
                    if (value == null) return;
                    setState(() => _selectedLimit = value);
                  },
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: _loadingQueue ? null : () => _loadQueue(reset: true),
                icon: const Icon(Icons.search, size: 16),
                label: const Text('Run Query'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary500,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          if (_zones.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _zones
                  .take(8)
                  .map(
                    (zone) => ActionChip(
                      label: Text(zone.zoneId),
                      onPressed: () {
                        setState(() {
                          _zoneIdController.text = zone.zoneId;
                        });
                      },
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
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
                    selectedColor: _statusBg(status),
                    checkmarkColor: _statusFg(status),
                    labelStyle: AppTextStyles.labelSm.copyWith(
                      color: _selectedStatuses.contains(status)
                          ? _statusFg(status)
                          : AppColors.neutral700,
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ),
    );
  }

  Widget _buildQueuePanel() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.neutral100),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Text(
                  'Queue (${_claims.length})',
                  style: AppTextStyles.headingSm.copyWith(fontSize: 15),
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
          ),
          if (_queueError != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.errorBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.errorFg.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                _queueError!,
                style: AppTextStyles.bodySm.copyWith(color: AppColors.errorFg),
              ),
            ),
          const Divider(height: 1, color: AppColors.neutral100),
          _buildQueueHeader(),
          const Divider(height: 1, color: AppColors.neutral100),
          Expanded(
            child: _claims.isEmpty
                ? Center(
                    child: Text(
                      _loadingQueue
                          ? 'Consultando cola...'
                          : 'No hay claims para los filtros actuales.',
                      style: AppTextStyles.bodySm,
                    ),
                  )
                : ListView.separated(
                    itemCount: _claims.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: AppColors.neutral100),
                    itemBuilder: (context, index) {
                      final item = _claims[index];
                      final selected = item.claimId == _selectedClaimId;
                      return InkWell(
                        onTap: () => _loadDetail(item.claimId),
                        child: Container(
                          color: selected
                              ? AppColors.primary50.withValues(alpha: 0.55)
                              : Colors.transparent,
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 120,
                                child: Text(
                                  item.claimId,
                                  style: AppTextStyles.bodyXs.copyWith(
                                    color: AppColors.neutral800,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  item.merchantName ?? item.merchantId,
                                  style: AppTextStyles.bodySm.copyWith(
                                    color: AppColors.neutral900,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 10),
                              _StatusBadge(
                                label: item.claimStatus.label,
                                background: _statusBg(item.claimStatus),
                                foreground: _statusFg(item.claimStatus),
                              ),
                              const SizedBox(width: 10),
                              SizedBox(
                                width: 82,
                                child: Text(
                                  item.categoryId ?? '-',
                                  style: AppTextStyles.bodyXs,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 10),
                              SizedBox(
                                width: 120,
                                child: Text(
                                  _formatDate(item.updatedAtMillis),
                                  style: AppTextStyles.bodyXs,
                                  textAlign: TextAlign.right,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (_nextCursor != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed:
                      _loadingQueue ? null : () => _loadQueue(reset: false),
                  icon: const Icon(Icons.expand_more, size: 16),
                  label: const Text('Load more'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.neutral700,
                    side: const BorderSide(color: AppColors.neutral300),
                    textStyle: AppTextStyles.labelSm,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQueueHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text('Claim', style: AppTextStyles.labelSm),
          ),
          Expanded(child: Text('Merchant', style: AppTextStyles.labelSm)),
          const SizedBox(width: 10),
          SizedBox(
            width: 95,
            child: Text('Status', style: AppTextStyles.labelSm),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 82,
            child: Text('Category', style: AppTextStyles.labelSm),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 120,
            child: Text(
              'Updated',
              style: AppTextStyles.labelSm,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailPanel() {
    if (_loadingDetail && _detail == null) {
      return Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.neutral100),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.primary500),
        ),
      );
    }

    if (_detailError != null) {
      return Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.neutral100),
        ),
        child: Center(
          child: Text(
            _detailError!,
            style: AppTextStyles.bodySm.copyWith(color: AppColors.errorFg),
          ),
        ),
      );
    }

    final detail = _detail;
    if (detail == null) {
      return Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.neutral100),
        ),
        child: Center(
          child: Text(
            'Selecciona un claim para ver detalle.',
            style: AppTextStyles.bodySm,
          ),
        ),
      );
    }

    final timeline = _buildTimeline(detail);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.neutral100),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Text(
                  'Claim Detail',
                  style: AppTextStyles.headingSm.copyWith(fontSize: 15),
                ),
                const SizedBox(width: 8),
                _StatusBadge(
                  label: detail.userVisibleStatus.label,
                  background: _statusBg(detail.userVisibleStatus),
                  foreground: _statusFg(detail.userVisibleStatus),
                ),
                const Spacer(),
                if (_loadingDetail)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.neutral100),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionCard(
                    title: 'Summary',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _kv('Claim ID', detail.claimId),
                        _kv(
                          'Merchant',
                          detail.merchantName ?? detail.merchantId,
                        ),
                        _kv('User ID', detail.userId),
                        _kv('Zone', detail.zoneId ?? '-'),
                        _kv('Category', detail.categoryId ?? '-'),
                        _kv('Declared role', detail.declaredRole ?? '-'),
                        _kv('Status (internal)', detail.claimStatus.apiValue),
                        _kv('Workflow', detail.internalWorkflowStatus ?? '-'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  _SectionCard(
                    title: 'Evidence and consent',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _kv(
                          'Storefront uploaded',
                          detail.storefrontPhotoUploaded ? 'Yes' : 'No',
                        ),
                        _kv(
                          'Ownership document uploaded',
                          detail.ownershipDocumentUploaded ? 'Yes' : 'No',
                        ),
                        _kv('Evidence files', '${detail.evidenceFiles.length}'),
                        _kv(
                          'Data processing consent',
                          detail.hasAcceptedDataProcessingConsent
                              ? 'Yes'
                              : 'No',
                        ),
                        _kv(
                          'Legitimacy declaration',
                          detail.hasAcceptedLegitimacyDeclaration
                              ? 'Yes'
                              : 'No',
                        ),
                        if (detail.evidenceFiles.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          ...detail.evidenceFiles.map(
                            (file) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                '- ${file.kind} | ${file.originalFileName ?? file.id} | ${file.sizeBytes} bytes',
                                style: AppTextStyles.bodyXs,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  _SectionCard(
                    title: 'Sensitive data (masked)',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _kv(
                          'Authenticated email',
                          detail.authenticatedEmail ?? '-',
                        ),
                        _kv('Phone', detail.phoneMasked ?? '-'),
                        _kv(
                          'Claimant name',
                          detail.claimantDisplayNameMasked ?? '-',
                        ),
                        _kv('Claimant note', detail.claimantNoteMasked ?? '-'),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: SensitiveFieldKind.values
                              .map(
                                (field) => FilterChip(
                                  selected: _revealFields.contains(field),
                                  onSelected: (enabled) =>
                                      _toggleRevealField(field, enabled),
                                  label: Text(_sensitiveLabel(field)),
                                ),
                              )
                              .toList(growable: false),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _revealReasonController,
                          decoration: const InputDecoration(
                            labelText: 'Reveal reason code',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            FilledButton.icon(
                              onPressed: _runningAction ? null : _runReveal,
                              icon: const Icon(Icons.visibility, size: 16),
                              label: const Text('Reveal'),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.neutral900,
                                foregroundColor: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (_revealExpiresAt != null)
                              Text(
                                'Expires: ${_formatDate(_revealExpiresAt!.millisecondsSinceEpoch)}',
                                style: AppTextStyles.bodyXs,
                              ),
                          ],
                        ),
                        if (_revealedValues.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.infoBg,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.primary200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: _revealedValues.entries
                                  .map(
                                    (entry) => Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Text(
                                        '${_sensitiveLabel(entry.key)}: ${entry.value}',
                                        style: AppTextStyles.bodySm.copyWith(
                                          color: AppColors.neutral900,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(growable: false),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  _SectionCard(
                    title: 'Validation and resolution context',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _kv(
                          'Auto validation reason',
                          detail.autoValidationReasonCode ?? '-',
                        ),
                        _kv('Conflict type', detail.conflictType ?? '-'),
                        _kv(
                          'Duplicate of claim',
                          detail.duplicateOfClaimId ?? '-',
                        ),
                        _kv('Review reason', detail.reviewReasonCode ?? '-'),
                        _kv('Review notes', detail.reviewNotes ?? '-'),
                        _kv('Reviewed by', detail.reviewedByUid ?? '-'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  _SectionCard(
                    title: 'Timeline',
                    child: timeline.isEmpty
                        ? Text(
                            'Sin eventos de tiempo.',
                            style: AppTextStyles.bodySm,
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: timeline
                                .map(
                                  (entry) => Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Text(
                                      '${_formatDate(entry.millis)} - ${entry.label}',
                                      style: AppTextStyles.bodySm,
                                    ),
                                  ),
                                )
                                .toList(growable: false),
                          ),
                  ),
                  const SizedBox(height: 10),
                  _SectionCard(
                    title: 'Manual actions',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            SizedBox(
                              width: 250,
                              child: DropdownMenu<MerchantClaimStatus>(
                                initialSelection: _resolveTargetStatus,
                                label: const Text('Resolve status'),
                                dropdownMenuEntries: _resolveStatuses
                                    .map(
                                      (status) => DropdownMenuEntry<
                                          MerchantClaimStatus>(
                                        value: status,
                                        label: status.label,
                                      ),
                                    )
                                    .toList(growable: false),
                                onSelected: (value) {
                                  if (value == null) return;
                                  setState(() => _resolveTargetStatus = value);
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: _runningAction ? null : _runEvaluate,
                              icon: const Icon(Icons.bolt, size: 16),
                              label: const Text('Re-evaluate'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.neutral700,
                                side: const BorderSide(
                                  color: AppColors.neutral300,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _resolveReasonController,
                          decoration: const InputDecoration(
                            labelText: 'Review reason code (optional)',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _resolveNotesController,
                          decoration: const InputDecoration(
                            labelText: 'Review notes (optional)',
                            border: OutlineInputBorder(),
                            alignLabelWithHint: true,
                          ),
                          minLines: 2,
                          maxLines: 4,
                        ),
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          onPressed: _runningAction ? null : _runResolve,
                          icon: const Icon(Icons.task_alt, size: 16),
                          label: const Text('Resolve claim'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary500,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<_TimelineEntry> _buildTimeline(MerchantClaimDetail detail) {
    final events = <_TimelineEntry>[
      if (detail.createdAtMillis != null)
        _TimelineEntry(label: 'Created', millis: detail.createdAtMillis!),
      if (detail.submittedAtMillis != null)
        _TimelineEntry(label: 'Submitted', millis: detail.submittedAtMillis!),
      if (detail.reviewedAtMillis != null)
        _TimelineEntry(label: 'Reviewed', millis: detail.reviewedAtMillis!),
      if (detail.lastStatusAtMillis != null)
        _TimelineEntry(
          label: 'Last status change',
          millis: detail.lastStatusAtMillis!,
        ),
      if (detail.updatedAtMillis != null)
        _TimelineEntry(label: 'Updated', millis: detail.updatedAtMillis!),
    ];
    events.sort((a, b) => a.millis.compareTo(b.millis));
    return events;
  }

  String _sensitiveLabel(SensitiveFieldKind field) {
    return switch (field) {
      SensitiveFieldKind.phone => 'Phone',
      SensitiveFieldKind.claimantDisplayName => 'Claimant name',
      SensitiveFieldKind.claimantNote => 'Claimant note',
    };
  }

  Widget _kv(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 180,
            child: Text(
              label,
              style: AppTextStyles.bodyXs.copyWith(color: AppColors.neutral600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.bodySm.copyWith(color: AppColors.neutral900),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTextStyles.bodyXs.copyWith(
          color: foreground,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.neutral50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.labelMd),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _TimelineEntry {
  const _TimelineEntry({required this.label, required this.millis});

  final String label;
  final int millis;
}
