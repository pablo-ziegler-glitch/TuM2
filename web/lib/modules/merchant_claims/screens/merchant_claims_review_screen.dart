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
  final Set<SensitiveFieldKind> _revealFields = {...SensitiveFieldKind.values};

  List<ZoneOption> _zones = const [];
  String? _selectedProvince;
  String? _selectedDepartment;
  String? _selectedCityZoneId;

  int _selectedLimit = 20;
  bool _loadingQueue = false;
  String? _queueError;
  List<MerchantClaimReviewItem> _claims = const [];
  MerchantClaimReviewCursor? _nextCursor;

  String? _selectedClaimId;
  bool _loadingDetail = false;
  String? _detailError;
  MerchantClaimDetail? _detail;
  bool _detailView = false;

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

  List<String> _provinceOptions() {
    final values = _zones
        .map((zone) => zone.provinceName.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);
    values.sort();
    return values;
  }

  List<String> _departmentOptions(String province) {
    final target = province.trim();
    final values = _zones
        .where((zone) => zone.provinceName.trim() == target)
        .map((zone) => zone.departmentName.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);
    values.sort();
    return values;
  }

  List<ZoneOption> _cityOptions({
    required String province,
    required String department,
  }) {
    final targetProvince = province.trim();
    final targetDepartment = department.trim();
    final values = _zones
        .where(
          (zone) =>
              zone.provinceName.trim() == targetProvince &&
              zone.departmentName.trim() == targetDepartment,
        )
        .toList(growable: false);
    values
        .sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    return values;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _resolveReasonController.dispose();
    _resolveNotesController.dispose();
    _revealReasonController.dispose();
    super.dispose();
  }

  Future<void> _loadZones() async {
    try {
      final zones = await _zonesRepository.fetchAvailableZones();
      if (!mounted) return;
      setState(() {
        _zones = zones;
        final provinces = _provinceOptions();
        if (_selectedProvince == null && provinces.isNotEmpty) {
          _selectedProvince = provinces.first;
        }
        final province = _selectedProvince;
        if (province != null) {
          final departments = _departmentOptions(province);
          if (departments.isEmpty) {
            _selectedDepartment = null;
            _selectedCityZoneId = null;
          } else {
            if (_selectedDepartment == null ||
                !departments.contains(_selectedDepartment)) {
              _selectedDepartment = departments.first;
              _selectedCityZoneId = null;
            }
            final department = _selectedDepartment;
            if (department != null) {
              final cities = _cityOptions(
                province: province,
                department: department,
              );
              if (_selectedCityZoneId != null &&
                  !cities.any((zone) => zone.zoneId == _selectedCityZoneId)) {
                _selectedCityZoneId = null;
              }
            }
          }
        }
      });
    } catch (error) {
      if (!mounted) return;
      _showSnack(
        'No pudimos cargar ciudades/zonas. Reintentá en unos segundos.',
        isError: true,
      );
      setState(() => _zones = const []);
    }
  }

  Future<void> _loadQueue({required bool reset}) async {
    if (_loadingQueue) return;
    final province = _selectedProvince?.trim() ?? '';
    final department = _selectedDepartment?.trim() ?? '';
    if (province.isEmpty || department.isEmpty) {
      setState(() {
        _queueError =
            'Seleccioná provincia y departamento para consultar la cola.';
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

    final matchingZones = _cityOptions(
      province: province,
      department: department,
    );
    if (matchingZones.isEmpty) {
      if (!mounted) return;
      setState(() {
        _loadingQueue = false;
        _queueError =
            'No encontramos ciudades para ese departamento/provincia.';
        if (reset) {
          _claims = const [];
          _nextCursor = null;
        }
      });
      return;
    }

    final selectedCityZoneId = _selectedCityZoneId?.trim();
    final selectedZoneId =
        selectedCityZoneId == null || selectedCityZoneId.isEmpty
            ? null
            : selectedCityZoneId;

    try {
      final page = await _claimsRepository.listForReview(
        filters: MerchantClaimReviewFilters(
          provinceName: province,
          departmentName: department,
          zoneId: selectedZoneId,
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
        _queueError = error.message ?? 'No pudimos cargar la cola de reclamos.';
        if (reset) {
          _claims = const [];
          _nextCursor = null;
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _queueError = 'No pudimos cargar la cola de reclamos.';
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
      _detailView = true;
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
        _detailError = 'No pudimos cargar el detalle del reclamo.';
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
      _showSnack('Reclamo reevaluado: ${result.claimStatus.label}.');
      setState(() => _selectedClaimId = claimId);
      await _loadQueue(reset: true);
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      _showSnack(
        error.message ?? 'No pudimos reevaluar el reclamo.',
        isError: true,
      );
    } catch (_) {
      if (!mounted) return;
      _showSnack('No pudimos reevaluar el reclamo.', isError: true);
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
      _showSnack('Reclamo resuelto: ${result.claimStatus.label}.');
      setState(() => _selectedClaimId = claimId);
      await _loadQueue(reset: true);
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      _showSnack(
        error.message ?? 'No pudimos resolver el reclamo.',
        isError: true,
      );
    } catch (_) {
      if (!mounted) return;
      _showSnack('No pudimos resolver el reclamo.', isError: true);
    } finally {
      if (mounted) setState(() => _runningAction = false);
    }
  }

  Future<void> _runReveal() async {
    final claimId = _selectedClaimId;
    if (claimId == null || _runningAction) return;
    if (_revealFields.isEmpty) {
      _showSnack(
        'Seleccioná al menos un campo para revelar.',
        isError: true,
      );
      return;
    }
    final reason = _revealReasonController.text.trim();
    if (reason.isEmpty) {
      _showSnack(
        'El código de motivo es obligatorio para revelar.',
        isError: true,
      );
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
      _showSnack('Revelación aplicada de forma temporal y auditada.');
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

  TextStyle _headlineStyle({
    double? size,
    FontWeight weight = FontWeight.w800,
    Color? color,
    double? letterSpacing,
  }) {
    return AppTextStyles.headingMd.copyWith(
      fontFamily: 'Manrope',
      fontSize: size,
      fontWeight: weight,
      color: color ?? AppColors.neutral900,
      letterSpacing: letterSpacing,
    );
  }

  TextStyle _labelStyle({Color? color, FontWeight? weight}) {
    return AppTextStyles.labelSm.copyWith(
      fontFamily: 'Inter',
      color: color ?? AppColors.neutral700,
      fontWeight: weight,
    );
  }

  TextStyle _bodyStyle({Color? color, FontWeight? weight}) {
    return AppTextStyles.bodySm.copyWith(
      fontFamily: 'Inter',
      color: color ?? AppColors.neutral700,
      fontWeight: weight,
    );
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
    final detail = _detail;
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: _detailView && detail != null
            ? _buildDetailWorkspace(detail)
            : _buildTriageWorkspace(),
      ),
    );
  }

  Widget _buildTriageWorkspace() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 12),
        _buildFiltersCard(),
        const SizedBox(height: 12),
        _buildTriageMetrics(),
        const SizedBox(height: 12),
        Expanded(child: _buildQueuePanel()),
      ],
    );
  }

  Widget _buildDetailWorkspace(MerchantClaimDetail detail) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDetailHeader(detail),
        const SizedBox(height: 12),
        Expanded(child: _buildDetailPanel()),
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'CONSOLA DE AUDITORÍA',
              style: _labelStyle(color: AppColors.primary600).copyWith(
                letterSpacing: 1.1,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Triaje de reclamos',
              style: _headlineStyle(
                size: 24,
                color: AppColors.primary700,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
        const SizedBox(width: 18),
        Expanded(
          child: SizedBox(
            height: 40,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar por ID de reclamo...',
                hintStyle: _bodyStyle(color: AppColors.neutral600),
                filled: true,
                fillColor: AppColors.neutral100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: const Icon(Icons.search, size: 18),
              ),
              onSubmitted: (raw) {
                final query = raw.trim();
                if (query.isEmpty) return;
                final match = _claims
                    .where((item) => item.claimId
                        .toLowerCase()
                        .contains(query.toLowerCase()))
                    .toList(growable: false);
                if (match.isEmpty) {
                  _showSnack('No encontramos ese reclamo en la cola actual.',
                      isError: true);
                  return;
                }
                _loadDetail(match.first.claimId);
              },
            ),
          ),
        ),
        IconButton(
          tooltip: 'Notificaciones',
          onPressed: () {},
          icon: const Icon(Icons.notifications_none),
        ),
        IconButton(
          tooltip: 'Ayuda',
          onPressed: () {},
          icon: const Icon(Icons.help_outline),
        ),
        OutlinedButton.icon(
          onPressed: _loadingQueue ? null : () => _loadQueue(reset: true),
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('Actualizar'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.neutral700,
            side: const BorderSide(color: AppColors.neutral300),
            textStyle: AppTextStyles.labelSm,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailHeader(MerchantClaimDetail detail) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextButton.icon(
            onPressed: () {
              setState(() => _detailView = false);
            },
            icon: const Icon(Icons.arrow_back, size: 16),
            label: const Text('Volver al triaje'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.neutral700,
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                detail.claimId,
                style: _headlineStyle(
                  size: 23,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(width: 8),
              _StatusBadge(
                label: detail.userVisibleStatus.label.toUpperCase(),
                background: _statusBg(detail.userVisibleStatus),
                foreground: _statusFg(detail.userVisibleStatus),
              ),
              const Spacer(),
              OutlinedButton(
                onPressed: () {},
                child: const Text('Exportar evidencia'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _runningAction
                    ? null
                    : () {
                        setState(() {
                          _resolveTargetStatus =
                              MerchantClaimStatus.conflictDetected;
                        });
                        _runResolve();
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary500,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Marcar para escalar'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Asignado a: Revisor humano',
            style: _bodyStyle().copyWith(fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _buildTriageMetrics() {
    final highRisk = _claims
        .where((item) =>
            item.hasConflict ||
            item.hasDuplicate ||
            item.riskPriority == 'high' ||
            item.riskPriority == 'critical')
        .length;
    final needInfo = _claims
        .where((item) =>
            item.claimStatus == MerchantClaimStatus.needsMoreInfo ||
            item.autoValidationReasons.contains('missing_storefront_photo') ||
            item.autoValidationReasons
                .contains('missing_basic_relationship_document') ||
            item.autoValidationReasons
                .contains('missing_category_required_evidence'))
        .length;
    return Row(
      children: [
        Expanded(
          flex: 7,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'VELOCIDAD DE COLA',
                        style: _labelStyle().copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_claims.length}',
                        style: _headlineStyle(size: 28).copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      minHeight: 12,
                      value: _claims.isEmpty
                          ? 0
                          : (_claims.length.clamp(1, 100) / 100),
                      backgroundColor: AppColors.neutral100,
                      color: AppColors.primary500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 3,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary600,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ACCIONES PRIORITARIAS',
                  style: _labelStyle(color: Colors.white.withValues(alpha: 0.9))
                      .copyWith(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 10),
                _priorityLine('$highRisk de alto riesgo pendientes'),
                const SizedBox(height: 6),
                _priorityLine('$needInfo reclamos con información faltante'),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {},
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.12),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('VER COLA DE ALTO RIESGO'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _priorityLine(String text) {
    return Row(
      children: [
        const Icon(Icons.priority_high, color: Colors.white, size: 16),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: _bodyStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildFiltersCard() {
    final provinceOptions = _provinceOptions();
    final selectedProvince = _selectedProvince;
    final departmentOptions = selectedProvince == null
        ? const <String>[]
        : _departmentOptions(selectedProvince);
    final selectedDepartment = _selectedDepartment;
    final cityOptions = (selectedProvince == null || selectedDepartment == null)
        ? const <ZoneOption>[]
        : _cityOptions(
            province: selectedProvince,
            department: selectedDepartment,
          );

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
                width: 220,
                child: DropdownMenu<String>(
                  width: 220,
                  enabled: provinceOptions.isNotEmpty,
                  enableFilter: true,
                  enableSearch: true,
                  initialSelection: _selectedProvince,
                  label: const Text('Provincia *'),
                  dropdownMenuEntries: provinceOptions
                      .map(
                        (item) =>
                            DropdownMenuEntry<String>(value: item, label: item),
                      )
                      .toList(growable: false),
                  onSelected: (value) {
                    if (value == null) return;
                    setState(() {
                      _selectedProvince = value;
                      final departments = _departmentOptions(value);
                      _selectedDepartment =
                          departments.isEmpty ? null : departments.first;
                      _selectedCityZoneId = null;
                    });
                  },
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 220,
                child: DropdownMenu<String>(
                  width: 220,
                  enabled:
                      selectedProvince != null && departmentOptions.isNotEmpty,
                  enableFilter: true,
                  enableSearch: true,
                  initialSelection: _selectedDepartment,
                  label: const Text('Departamento *'),
                  dropdownMenuEntries: departmentOptions
                      .map(
                        (item) =>
                            DropdownMenuEntry<String>(value: item, label: item),
                      )
                      .toList(growable: false),
                  onSelected: (value) {
                    if (value == null) return;
                    setState(() {
                      _selectedDepartment = value;
                      _selectedCityZoneId = null;
                    });
                  },
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 280,
                child: DropdownMenu<String>(
                  width: 280,
                  enabled: selectedDepartment != null && cityOptions.isNotEmpty,
                  enableFilter: true,
                  enableSearch: true,
                  initialSelection: _selectedCityZoneId,
                  label: const Text('Ciudad (opcional)'),
                  hintText: 'Todas las ciudades del departamento',
                  dropdownMenuEntries: cityOptions
                      .map(
                        (zone) => DropdownMenuEntry<String>(
                          value: zone.zoneId,
                          label: zone.label,
                        ),
                      )
                      .toList(growable: false),
                  onSelected: (value) {
                    setState(() {
                      _selectedCityZoneId = value;
                    });
                  },
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 110,
                child: DropdownMenu<int>(
                  initialSelection: _selectedLimit,
                  label: const Text('Límite'),
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
                label: const Text('Consultar'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary500,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          if (cityOptions.isNotEmpty && _selectedCityZoneId == null) ...[
            const SizedBox(height: 8),
            Text(
              'Modo departamento activo: se buscará en todo el departamento con paginación.',
              style: AppTextStyles.bodyXs.copyWith(
                color: AppColors.neutral700,
                fontFamily: 'Inter',
              ),
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
                  'Cola de reclamos (${_claims.length})',
                  style: _headlineStyle(size: 17, weight: FontWeight.w700),
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
                style: _bodyStyle(color: AppColors.errorFg),
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
                          : 'No hay reclamos para los filtros actuales.',
                      style: _bodyStyle(),
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
                                width: 110,
                                child: Text(
                                  item.claimId,
                                  style: AppTextStyles.bodyXs.copyWith(
                                    fontFamily: 'Inter',
                                    color: AppColors.neutral800,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  item.merchantName ?? item.merchantId,
                                  style: AppTextStyles.bodySm.copyWith(
                                    fontFamily: 'Inter',
                                    color: AppColors.neutral900,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 10),
                              SizedBox(
                                width: 170,
                                child: Text(
                                  _zoneLabel(item.zoneId),
                                  style: AppTextStyles.bodyXs.copyWith(
                                    fontFamily: 'Inter',
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
                                width: 70,
                                child: Text(
                                  item.categoryId ?? '-',
                                  style: AppTextStyles.bodyXs,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 10),
                              SizedBox(
                                width: 60,
                                child: _riskFlag(item),
                              ),
                              const SizedBox(width: 10),
                              SizedBox(
                                width: 140,
                                child: Text(
                                  _maskIdentity(item.userId),
                                  style: AppTextStyles.bodyXs.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 10),
                              SizedBox(
                                width: 110,
                                child: Text(
                                  _formatDate(item.createdAtMillis),
                                  style: AppTextStyles.bodyXs.copyWith(
                                    fontFamily: 'Inter',
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                              const SizedBox(width: 10),
                              SizedBox(
                                width: 70,
                                child: TextButton(
                                  onPressed: () => _loadDetail(item.claimId),
                                  child: const Text('ABRIR'),
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
                  label: const Text('Cargar más'),
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
            width: 110,
            child: Text('ID de reclamo', style: _labelStyle()),
          ),
          Expanded(child: Text('Comercio', style: _labelStyle())),
          const SizedBox(width: 10),
          SizedBox(
            width: 170,
            child: Text('Zona', style: _labelStyle()),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 95,
            child: Text('Estado', style: _labelStyle()),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 70,
            child: Text('Categoría', style: _labelStyle()),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 60,
            child: Text('Riesgo', style: _labelStyle()),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 140,
            child: Text('Solicitante', style: _labelStyle()),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 110,
            child: Text(
              'Fecha',
              style: _labelStyle(),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 70,
            child: Text('Acción', style: _labelStyle()),
          ),
        ],
      ),
    );
  }

  Widget _riskFlag(MerchantClaimReviewItem item) {
    final high = item.hasConflict ||
        item.riskPriority == 'critical' ||
        item.riskPriority == 'high';
    final medium = item.hasDuplicate ||
        item.claimStatus == MerchantClaimStatus.needsMoreInfo ||
        item.riskPriority == 'medium';
    if (high) {
      return const Icon(Icons.warning_amber_rounded,
          color: AppColors.errorFg, size: 16);
    }
    if (medium) {
      return const Icon(Icons.error_outline,
          color: AppColors.warningFg, size: 16);
    }
    return const Icon(Icons.check_circle_outline,
        color: AppColors.secondary500, size: 16);
  }

  String _maskIdentity(String raw) {
    final value = raw.trim();
    if (value.length <= 4) return '******';
    final suffix = value.substring(value.length - 4);
    return '******$suffix';
  }

  String _zoneLabel(String zoneId) {
    final trimmed = zoneId.trim();
    if (trimmed.isEmpty) return '-';
    for (final zone in _zones) {
      if (zone.zoneId == trimmed) return zone.label;
    }
    return trimmed;
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
            'Seleccioná un reclamo para ver detalle.',
            style: _bodyStyle(),
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
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 1140;
            final detailContent = SingleChildScrollView(
              padding: const EdgeInsets.only(right: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Panel de investigación',
                        style:
                            _headlineStyle(size: 17, weight: FontWeight.w700),
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
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: 'Resumen del caso',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _kv('ID de reclamo', detail.claimId),
                        _kv('Comercio',
                            detail.merchantName ?? detail.merchantId),
                        _kv('Solicitante', _maskIdentity(detail.userId)),
                        _kv('Zona/Ciudad', _zoneLabel(detail.zoneId ?? '-')),
                        _kv('Categoría', detail.categoryId ?? '-'),
                        _kv('Rol declarado', detail.declaredRole ?? '-'),
                        _kv('Estado (interno)', detail.claimStatus.apiValue),
                        _kv('Flujo interno',
                            detail.internalWorkflowStatus ?? '-'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  _SectionCard(
                    title: 'Evidencia y consentimiento',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _kv(
                          'Foto de frente del local',
                          detail.storefrontPhotoUploaded ? 'Sí' : 'No',
                        ),
                        _kv(
                          'Documento de titularidad',
                          detail.ownershipDocumentUploaded ? 'Sí' : 'No',
                        ),
                        _kv('Archivos de evidencia',
                            '${detail.evidenceFiles.length}'),
                        _kv(
                          'Consentimiento de datos',
                          detail.hasAcceptedDataProcessingConsent ? 'Sí' : 'No',
                        ),
                        _kv(
                          'Declaración de legitimidad',
                          detail.hasAcceptedLegitimacyDeclaration ? 'Sí' : 'No',
                        ),
                        if (detail.evidenceFiles.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          ...detail.evidenceFiles.map(
                            (file) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                '- ${file.kind} | ${file.originalFileName ?? file.id} | ${file.sizeBytes} bytes',
                                style: AppTextStyles.bodyXs.copyWith(
                                  fontFamily: 'Inter',
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  _SectionCard(
                    title: 'Señales de revisión',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _kv(
                          'Motivo de validación automática',
                          detail.autoValidationReasonCode ?? '-',
                        ),
                        _kv(
                          'Motivos de validación automática',
                          detail.autoValidationReasons.isEmpty
                              ? '-'
                              : detail.autoValidationReasons.join(', '),
                        ),
                        _kv('Tiene conflicto',
                            detail.hasConflict ? 'Sí' : 'No'),
                        _kv(
                          'Tiene duplicado',
                          detail.hasDuplicate ? 'Sí' : 'No',
                        ),
                        _kv(
                          'Requiere revisión manual',
                          detail.requiresManualReview ? 'Sí' : 'No',
                        ),
                        _kv(
                          'Tipos de evidencia faltante',
                          detail.missingEvidenceTypes.isEmpty
                              ? '-'
                              : detail.missingEvidenceTypes.join(', '),
                        ),
                        _kv(
                          'Banderas de riesgo',
                          detail.riskFlags.isEmpty
                              ? '-'
                              : detail.riskFlags.join(', '),
                        ),
                        _kv('Prioridad de riesgo', detail.riskPriority ?? '-'),
                        _kv(
                          'Prioridad en cola',
                          detail.reviewQueuePriority?.toString() ?? '-',
                        ),
                        _kv('Tipo de conflicto', detail.conflictType ?? '-'),
                        _kv('Duplicado de reclamo',
                            detail.duplicateOfClaimId ?? '-'),
                        _kv('Motivo de revisión',
                            detail.reviewReasonCode ?? '-'),
                        _kv('Notas de revisión', detail.reviewNotes ?? '-'),
                        _kv('Revisado por', detail.reviewedByUid ?? '-'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  _SectionCard(
                    title: 'Línea de tiempo',
                    child: timeline.isEmpty
                        ? Text('Sin eventos de tiempo.', style: _bodyStyle())
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: timeline
                                .map(
                                  (entry) => Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Text(
                                      '${_formatDate(entry.millis)} - ${entry.label}',
                                      style: _bodyStyle(),
                                    ),
                                  ),
                                )
                                .toList(growable: false),
                          ),
                  ),
                ],
              ),
            );

            final verdictPanel =
                _buildAuditorsVerdictPanel(detail, compact: compact);
            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  verdictPanel,
                  const SizedBox(height: 12),
                  Expanded(child: detailContent),
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: detailContent),
                const SizedBox(width: 16),
                SizedBox(
                  width: 360,
                  height: constraints.maxHeight,
                  child: verdictPanel,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildAuditorsVerdictPanel(
    MerchantClaimDetail detail, {
    required bool compact,
  }) {
    final panelBody = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Veredicto del auditor',
          style: _headlineStyle(size: 18, weight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          'Definí la resolución final, ejecutá la acción y dejá trazabilidad clara.',
          style: _bodyStyle(color: AppColors.neutral600),
        ),
        const SizedBox(height: 6),
        Text(
          'Estado actual: ${detail.userVisibleStatus.label}',
          style: AppTextStyles.bodyXs.copyWith(
            fontFamily: 'Inter',
            color: AppColors.neutral700,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Revisor asignado: Revisor humano',
          style: AppTextStyles.bodyXs.copyWith(
            fontFamily: 'Inter',
            color: AppColors.neutral700,
          ),
        ),
        const SizedBox(height: 14),
        Text('Estado de resolución',
            style: _labelStyle(weight: FontWeight.w600)),
        const SizedBox(height: 6),
        DropdownMenu<MerchantClaimStatus>(
          initialSelection: _resolveTargetStatus,
          width: double.infinity,
          label: const Text('Definir veredicto'),
          dropdownMenuEntries: _resolveStatuses
              .map(
                (status) => DropdownMenuEntry<MerchantClaimStatus>(
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
        const SizedBox(height: 10),
        TextField(
          controller: _resolveReasonController,
          decoration: const InputDecoration(
            labelText: 'Código de motivo (opcional)',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _resolveNotesController,
          decoration: const InputDecoration(
            labelText: 'Notas de decisión (opcional)',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
          minLines: 2,
          maxLines: 4,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _runningAction ? null : _runEvaluate,
                icon: const Icon(Icons.bolt, size: 16),
                label: const Text('Re-evaluar'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.neutral700,
                  side: const BorderSide(color: AppColors.neutral300),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                onPressed: _runningAction ? null : _runResolve,
                icon: const Icon(Icons.task_alt, size: 16),
                label: const Text('Publicar veredicto'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary500,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Divider(height: 1, color: AppColors.neutral200),
        const SizedBox(height: 12),
        Text(
          'Datos sensibles',
          style: _headlineStyle(size: 15, weight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'Revelación temporal solo para auditoría. Toda acción queda auditada.',
          style: _bodyStyle(color: AppColors.neutral600),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: SensitiveFieldKind.values
              .map(
                (field) => FilterChip(
                  selected: _revealFields.contains(field),
                  onSelected: (enabled) => _toggleRevealField(field, enabled),
                  label: Text(_sensitiveLabel(field)),
                ),
              )
              .toList(growable: false),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _revealReasonController,
          decoration: const InputDecoration(
            labelText: 'Código de motivo de revelación',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _runningAction ? null : _runReveal,
          icon: const Icon(Icons.visibility, size: 16),
          label: const Text('Revelar campos sensibles'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.neutral900,
            foregroundColor: Colors.white,
          ),
        ),
        if (_revealExpiresAt != null) ...[
          const SizedBox(height: 6),
          Text(
            'Expira: ${_formatDate(_revealExpiresAt!.millisecondsSinceEpoch)}',
            style: AppTextStyles.bodyXs.copyWith(
              fontFamily: 'Inter',
              color: AppColors.neutral700,
            ),
          ),
        ],
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
                        style: _bodyStyle(color: AppColors.neutral900),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
        ],
      ],
    );

    final panel = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.neutral50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.neutral200),
      ),
      child: compact
          ? SingleChildScrollView(child: panelBody)
          : Column(
              children: [
                Expanded(child: SingleChildScrollView(child: panelBody)),
              ],
            ),
    );
    return panel;
  }

  List<_TimelineEntry> _buildTimeline(MerchantClaimDetail detail) {
    final events = <_TimelineEntry>[
      if (detail.createdAtMillis != null)
        _TimelineEntry(label: 'Creado', millis: detail.createdAtMillis!),
      if (detail.submittedAtMillis != null)
        _TimelineEntry(label: 'Enviado', millis: detail.submittedAtMillis!),
      if (detail.reviewedAtMillis != null)
        _TimelineEntry(label: 'Revisado', millis: detail.reviewedAtMillis!),
      if (detail.lastStatusAtMillis != null)
        _TimelineEntry(
          label: 'Último cambio de estado',
          millis: detail.lastStatusAtMillis!,
        ),
      if (detail.updatedAtMillis != null)
        _TimelineEntry(label: 'Actualizado', millis: detail.updatedAtMillis!),
    ];
    events.sort((a, b) => a.millis.compareTo(b.millis));
    return events;
  }

  String _sensitiveLabel(SensitiveFieldKind field) {
    return switch (field) {
      SensitiveFieldKind.phone => 'Teléfono',
      SensitiveFieldKind.claimantDisplayName => 'Nombre del solicitante',
      SensitiveFieldKind.claimantNote => 'Nota del solicitante',
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
              style: AppTextStyles.bodyXs.copyWith(
                fontFamily: 'Inter',
                color: AppColors.neutral600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: _bodyStyle(color: AppColors.neutral900),
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
          Text(
            title,
            style: AppTextStyles.labelMd.copyWith(
              fontFamily: 'Manrope',
              fontWeight: FontWeight.w700,
            ),
          ),
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
