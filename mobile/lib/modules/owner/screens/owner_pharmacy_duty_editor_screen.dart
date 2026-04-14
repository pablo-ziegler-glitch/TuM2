import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/feature_flags_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../duties/models/owner_pharmacy_duty.dart';
import '../duties/repositories/owner_pharmacy_duties_repository.dart';
import '../providers/owner_providers.dart';

class OwnerPharmacyDutyEditorExtra {
  const OwnerPharmacyDutyEditorExtra({this.duty});

  final OwnerPharmacyDuty? duty;
}

class OwnerPharmacyDutyEditorScreen extends ConsumerStatefulWidget {
  const OwnerPharmacyDutyEditorScreen({
    super.key,
    this.dutyId,
    this.initialDateKey,
    this.extra,
  });

  final String? dutyId;
  final String? initialDateKey;
  final OwnerPharmacyDutyEditorExtra? extra;

  @override
  ConsumerState<OwnerPharmacyDutyEditorScreen> createState() =>
      _OwnerPharmacyDutyEditorScreenState();
}

class _OwnerPharmacyDutyEditorScreenState
    extends ConsumerState<OwnerPharmacyDutyEditorScreen> {
  final OwnerPharmacyDutiesRepository _repository =
      OwnerPharmacyDutiesRepository();

  bool _loadingDuty = false;
  bool _saving = false;
  String? _errorMessage;
  OwnerPharmacyDuty? _duty;
  String _dateKey = '';
  TimeOfDay _startsAt = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _endsAt = const TimeOfDay(hour: 20, minute: 0);
  OwnerPharmacyDutyStatus _status = OwnerPharmacyDutyStatus.scheduled;

  bool get _isEditing => widget.dutyId != null;

  @override
  void initState() {
    super.initState();
    _dateKey = _resolveInitialDateKey();
    _hydrateFromExtra();
    if (_isEditing && _duty == null) {
      _loadDutyById();
    }
  }

  String _resolveInitialDateKey() {
    final explicit = (widget.initialDateKey ?? '').trim();
    if (explicit.length == 10) return explicit;
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  void _hydrateFromExtra() {
    final duty = widget.extra?.duty;
    if (duty == null) return;
    _duty = duty;
    _dateKey = duty.dateKey;
    _startsAt = TimeOfDay.fromDateTime(duty.startsAt.toLocal());
    _endsAt = TimeOfDay.fromDateTime(duty.endsAt.toLocal());
    _status = duty.status == OwnerPharmacyDutyStatus.cancelled
        ? OwnerPharmacyDutyStatus.cancelled
        : OwnerPharmacyDutyStatus.scheduled;
  }

  Future<void> _loadDutyById() async {
    final dutyId = widget.dutyId;
    if (dutyId == null || dutyId.isEmpty) return;
    setState(() {
      _loadingDuty = true;
      _errorMessage = null;
    });
    try {
      final duty = await _repository.getDutyById(dutyId: dutyId);
      if (!mounted) return;
      if (duty == null) {
        setState(() {
          _loadingDuty = false;
          _errorMessage = 'No encontramos el turno solicitado.';
        });
        return;
      }
      setState(() {
        _duty = duty;
        _dateKey = duty.dateKey;
        _startsAt = TimeOfDay.fromDateTime(duty.startsAt.toLocal());
        _endsAt = TimeOfDay.fromDateTime(duty.endsAt.toLocal());
        _status = duty.status == OwnerPharmacyDutyStatus.cancelled
            ? OwnerPharmacyDutyStatus.cancelled
            : OwnerPharmacyDutyStatus.scheduled;
        _loadingDuty = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingDuty = false;
        _errorMessage = 'No pudimos cargar el turno.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ownerMerchantAsync = ref.watch(ownerMerchantProvider);
    final dutiesEnabledAsync = ref.watch(ownerPharmacyDutiesEnabledProvider);

    return dutiesEnabledAsync.when(
      loading: _buildLoadingScaffold,
      error: (_, __) => _buildErrorScaffold('No se pudo cargar configuración.'),
      data: (enabled) {
        if (!enabled) {
          return _buildErrorScaffold('El módulo de turnos está deshabilitado.');
        }
        return ownerMerchantAsync.when(
          loading: _buildLoadingScaffold,
          error: (_, __) =>
              _buildErrorScaffold('No pudimos cargar tu comercio.'),
          data: (resolution) {
            final merchant = resolution.primaryMerchant;
            if (merchant == null || !merchant.isPharmacy) {
              return _buildErrorScaffold('No tenés una farmacia habilitada.');
            }

            return Scaffold(
              backgroundColor: AppColors.scaffoldBg,
              appBar: AppBar(
                backgroundColor: AppColors.surface,
                elevation: 0,
                title: Text(
                  _isEditing ? 'Editar turno' : 'Nuevo turno',
                  style: AppTextStyles.headingSm,
                ),
              ),
              body: Stack(
                children: [
                  ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: [
                      if (_errorMessage != null) _buildErrorCard(),
                      if (_loadingDuty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primary500,
                            ),
                          ),
                        )
                      else ...[
                        _buildDateCard(),
                        const SizedBox(height: 12),
                        _buildTimeCard(),
                        const SizedBox(height: 12),
                        _buildStatusCard(),
                        const SizedBox(height: 12),
                        _buildPreviewCard(),
                        const SizedBox(height: 16),
                        _buildActions(merchant.id),
                      ],
                    ],
                  ),
                  if (_saving)
                    Container(
                      color: AppColors.surface.withValues(alpha: 0.72),
                      alignment: Alignment.center,
                      child: const CircularProgressIndicator(
                        color: AppColors.primary500,
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Scaffold _buildLoadingScaffold() {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Text('Turnos de farmacia', style: AppTextStyles.headingSm),
      ),
      body: const Center(
        child: CircularProgressIndicator(color: AppColors.primary500),
      ),
    );
  }

  Scaffold _buildErrorScaffold(String message) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Text('Turnos de farmacia', style: AppTextStyles.headingSm),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(message, style: AppTextStyles.bodyMd),
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.errorBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _errorMessage!,
        style: AppTextStyles.bodySm.copyWith(color: AppColors.errorFg),
      ),
    );
  }

  Widget _buildDateCard() {
    return _section(
      title: 'Fecha',
      child: Text(_dateKey, style: AppTextStyles.headingSm),
    );
  }

  Widget _buildTimeCard() {
    return _section(
      title: 'Horario',
      child: Row(
        children: [
          Expanded(
            child: _timeField(
              label: 'Inicio',
              value: _startsAt.format(context),
              onTap: _pickStartsAt,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _timeField(
              label: 'Fin',
              value: _endsAt.format(context),
              onTap: _pickEndsAt,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    return _section(
      title: 'Estado',
      child: DropdownButtonFormField<OwnerPharmacyDutyStatus>(
        initialValue: _status,
        items: const [
          DropdownMenuItem(
            value: OwnerPharmacyDutyStatus.scheduled,
            child: Text('Publicado'),
          ),
          DropdownMenuItem(
            value: OwnerPharmacyDutyStatus.cancelled,
            child: Text('Borrador'),
          ),
        ],
        onChanged: _saving
            ? null
            : (value) {
                if (value == null) return;
                setState(() => _status = value);
              },
      ),
    );
  }

  Widget _buildPreviewCard() {
    final start = _startsAt.format(context);
    final end = _endsAt.format(context);
    final overnight = (_endsAt.hour * 60 + _endsAt.minute) <=
        (_startsAt.hour * 60 + _startsAt.minute);
    return _section(
      title: 'Vista previa',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_dateKey, style: AppTextStyles.labelMd),
          const SizedBox(height: 4),
          Text(
            '$start - $end${overnight ? ' (+1)' : ''}',
            style: AppTextStyles.headingSm,
          ),
        ],
      ),
    );
  }

  Widget _buildActions(String merchantId) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _saving ? null : () => _save(merchantId),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary500,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Text(_isEditing ? 'Guardar cambios' : 'Guardar turno'),
          ),
        ),
        if (_isEditing) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _saving || _duty == null ? null : () => _delete(_duty!),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Eliminar turno'),
          ),
        ],
      ],
    );
  }

  Widget _section({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.neutral100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.labelMd),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _timeField({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.neutral50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.neutral200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTextStyles.bodyXs),
            const SizedBox(height: 4),
            Text(value, style: AppTextStyles.labelMd),
          ],
        ),
      ),
    );
  }

  Future<void> _pickStartsAt() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _startsAt,
    );
    if (selected == null) return;
    setState(() => _startsAt = selected);
  }

  Future<void> _pickEndsAt() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _endsAt,
    );
    if (selected == null) return;
    setState(() => _endsAt = selected);
  }

  Future<void> _save(String merchantId) async {
    final startMinutes = _startsAt.hour * 60 + _startsAt.minute;
    final endMinutes = _endsAt.hour * 60 + _endsAt.minute;
    final overnight = endMinutes <= startMinutes;
    setState(() {
      _saving = true;
      _errorMessage = null;
    });
    try {
      await _repository.upsertDuty(
        merchantId: merchantId,
        dutyId: _duty?.id,
        date: _dateKey,
        startsAtIso: _toIsoUtc3(_dateKey, _startsAt, dayOffset: 0),
        endsAtIso: _toIsoUtc3(_dateKey, _endsAt, dayOffset: overnight ? 1 : 0),
        status: _status,
        expectedUpdatedAtMillis: _duty?.updatedAt?.millisecondsSinceEpoch,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on OwnerDutyException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'No pudimos guardar el turno.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete(OwnerPharmacyDuty duty) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar este turno?'),
        content: const Text('Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.errorFg),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _saving = true;
      _errorMessage = null;
    });
    try {
      await _repository.changeDutyStatus(
        dutyId: duty.id,
        status: OwnerPharmacyDutyStatus.cancelled,
        expectedUpdatedAtMillis: duty.updatedAt?.millisecondsSinceEpoch,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on OwnerDutyException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'No pudimos eliminar el turno.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _toIsoUtc3(
    String dateKey,
    TimeOfDay time, {
    required int dayOffset,
  }) {
    final chunks = dateKey.split('-');
    final y = int.tryParse(chunks[0]) ?? DateTime.now().year;
    final m = int.tryParse(chunks[1]) ?? DateTime.now().month;
    final d = int.tryParse(chunks[2]) ?? DateTime.now().day;
    final base = DateTime(y, m, d).add(Duration(days: dayOffset));
    final year = base.year.toString().padLeft(4, '0');
    final month = base.month.toString().padLeft(2, '0');
    final day = base.day.toString().padLeft(2, '0');
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    return '$year-$month-${day}T$hh:$mm:00-03:00';
  }
}
