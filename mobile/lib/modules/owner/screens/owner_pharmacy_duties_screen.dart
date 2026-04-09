import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/feature_flags_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../duties/models/owner_pharmacy_duty.dart';
import '../duties/repositories/owner_pharmacy_duties_repository.dart';
import '../providers/owner_providers.dart';

final ownerPharmacyDutiesRepositoryProvider =
    Provider<OwnerPharmacyDutiesRepository>((ref) {
  return OwnerPharmacyDutiesRepository();
});

class OwnerPharmacyDutiesScreen extends ConsumerStatefulWidget {
  const OwnerPharmacyDutiesScreen({super.key});

  @override
  ConsumerState<OwnerPharmacyDutiesScreen> createState() =>
      _OwnerPharmacyDutiesScreenState();
}

class _OwnerPharmacyDutiesScreenState
    extends ConsumerState<OwnerPharmacyDutiesScreen> {
  final DateFormat _monthFormat = DateFormat('MMMM yyyy', 'es');
  final DateFormat _timeFormat = DateFormat('HH:mm');

  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selectedDate = DateTime.now();
  bool _loadingMonth = false;
  bool _saving = false;
  String? _feedbackMessage;
  bool _feedbackError = false;
  String? _loadedKey;
  OwnerDutyConflict? _lastConflict;

  List<OwnerPharmacyDuty> _monthDuties = const [];
  String? _editingDutyId;
  int? _editingExpectedUpdatedAt;
  TimeOfDay _startsAt = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _endsAt = const TimeOfDay(hour: 20, minute: 0);
  OwnerPharmacyDutyStatus _draftStatus = OwnerPharmacyDutyStatus.draft;

  @override
  Widget build(BuildContext context) {
    final dutiesEnabledAsync = ref.watch(ownerPharmacyDutiesEnabledProvider);
    final ownerMerchantAsync = ref.watch(ownerMerchantProvider);

    return dutiesEnabledAsync.when(
      loading: _buildLoadingScaffold,
      error: (_, __) => _buildErrorScaffold(
        'No se pudo consultar la configuración del módulo.',
      ),
      data: (enabled) {
        if (!enabled) {
          return _buildErrorScaffold(
            'El módulo de turnos de farmacia está deshabilitado temporalmente.',
          );
        }

        return ownerMerchantAsync.when(
          loading: _buildLoadingScaffold,
          error: (_, __) => _buildErrorScaffold(
            'No pudimos cargar tu comercio.',
          ),
          data: (resolution) {
            final merchant = resolution.primaryMerchant;
            if (merchant == null) {
              return _buildErrorScaffold(
                'No encontramos un comercio asociado a tu usuario.',
              );
            }
            if (!merchant.isPharmacy) {
              return _buildErrorScaffold(
                'Solo farmacias pueden usar este módulo.',
              );
            }

            _ensureMonthLoaded(merchant.id);
            final selectedDateKey = _dateKey(_selectedDate);
            final selectedDuties = _monthDuties
                .where((item) => item.dateKey == selectedDateKey)
                .toList(growable: false);

            return Scaffold(
              backgroundColor: AppColors.scaffoldBg,
              appBar: AppBar(
                backgroundColor: AppColors.surface,
                elevation: 0,
                title: const Text('Turnos de farmacia',
                    style: AppTextStyles.headingSm),
              ),
              body: Column(
                children: [
                  if (_feedbackMessage != null) _buildFeedbackBanner(),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () => _loadMonth(merchant.id),
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        children: [
                          _buildHeroCard(),
                          const SizedBox(height: 12),
                          _buildMonthHeader(merchant.id),
                          const SizedBox(height: 10),
                          _buildCalendarCard(),
                          const SizedBox(height: 14),
                          _buildLegend(),
                          if (_lastConflict != null) ...[
                            const SizedBox(height: 14),
                            _buildConflictCard(_lastConflict!),
                          ],
                          const SizedBox(height: 14),
                          _buildSelectedDateCard(selectedDuties),
                          const SizedBox(height: 16),
                          _buildEditorCard(
                            merchantId: merchant.id,
                            selectedDateKey: selectedDateKey,
                          ),
                        ],
                      ),
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
          child: Text(
            message,
            style: AppTextStyles.bodyMd,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildMonthHeader(String merchantId) {
    return Row(
      children: [
        IconButton(
          onPressed: _loadingMonth
              ? null
              : () {
                  setState(() {
                    _focusedMonth =
                        DateTime(_focusedMonth.year, _focusedMonth.month - 1);
                  });
                  _loadMonth(merchantId);
                },
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Text(
            _capitalize(_monthFormat.format(_focusedMonth)),
            style: AppTextStyles.headingSm,
            textAlign: TextAlign.center,
          ),
        ),
        IconButton(
          onPressed: _loadingMonth
              ? null
              : () {
                  setState(() {
                    _focusedMonth =
                        DateTime(_focusedMonth.year, _focusedMonth.month + 1);
                  });
                  _loadMonth(merchantId);
                },
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  Widget _buildHeroCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0044AA), Color(0xFF0E5BD8)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Gestión mensual de guardias',
            style: AppTextStyles.headingMd.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 6),
          Text(
            'Cargá y publicá tus turnos para que tus vecinos te encuentren cuando más te necesitan.',
            style: AppTextStyles.bodySm.copyWith(
              color: Colors.white.withValues(alpha: 0.92),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarCard() {
    final daysInMonth = DateUtils.getDaysInMonth(
      _focusedMonth.year,
      _focusedMonth.month,
    );
    final firstWeekday =
        DateTime(_focusedMonth.year, _focusedMonth.month, 1).weekday - 1;
    final totalSlots = ((firstWeekday + daysInMonth + 6) ~/ 7) * 7;
    final statusByDate = <String, OwnerPharmacyDutyStatus>{};
    for (final duty in _monthDuties) {
      final existing = statusByDate[duty.dateKey];
      if (existing == OwnerPharmacyDutyStatus.published) continue;
      if (duty.status == OwnerPharmacyDutyStatus.published) {
        statusByDate[duty.dateKey] = duty.status;
        continue;
      }
      statusByDate[duty.dateKey] ??= duty.status;
    }

    const weekdays = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.neutral100),
      ),
      child: Column(
        children: [
          Row(
            children: weekdays
                .map(
                  (day) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        day,
                        style: AppTextStyles.bodyXs.copyWith(
                          color: AppColors.neutral700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
          GridView.builder(
            itemCount: totalSlots,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 0.95,
            ),
            itemBuilder: (context, index) {
              final dayNumber = index - firstWeekday + 1;
              if (dayNumber < 1 || dayNumber > daysInMonth) {
                return const SizedBox.shrink();
              }

              final dayDate = DateTime(
                _focusedMonth.year,
                _focusedMonth.month,
                dayNumber,
              );
              final dayKey = _dateKey(dayDate);
              final selected = DateUtils.isSameDay(dayDate, _selectedDate);
              final status = statusByDate[dayKey];

              return InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => setState(() => _selectedDate = dayDate),
                child: Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary50 : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected
                          ? AppColors.primary400
                          : AppColors.neutral100,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$dayNumber',
                        style: AppTextStyles.labelSm.copyWith(
                          color: AppColors.neutral900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      _buildDayStatusDot(status),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDayStatusDot(OwnerPharmacyDutyStatus? status) {
    if (status == null) {
      return Container(
        width: 6,
        height: 6,
        decoration: const BoxDecoration(
          color: AppColors.neutral200,
          shape: BoxShape.circle,
        ),
      );
    }

    Color color;
    switch (status) {
      case OwnerPharmacyDutyStatus.published:
        color = AppColors.errorFg;
      case OwnerPharmacyDutyStatus.cancelled:
        color = AppColors.neutral500;
      case OwnerPharmacyDutyStatus.draft:
        color = AppColors.tertiary500;
    }

    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  Widget _buildLegend() {
    Widget item(Color color, String label) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label, style: AppTextStyles.bodyXs),
        ],
      );
    }

    return Wrap(
      spacing: 14,
      runSpacing: 8,
      children: [
        item(AppColors.neutral200, 'Sin turno'),
        item(AppColors.tertiary500, 'Borrador'),
        item(AppColors.errorFg, 'Publicado'),
      ],
    );
  }

  Widget _buildSelectedDateCard(List<OwnerPharmacyDuty> selectedDuties) {
    final dayLabel = DateFormat('EEEE d MMMM', 'es').format(_selectedDate);
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
          Text(
            _capitalize(dayLabel),
            style: AppTextStyles.headingSm,
          ),
          const SizedBox(height: 10),
          if (selectedDuties.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.local_pharmacy_outlined,
                          color: AppColors.primary600,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Todavía no cargaste turnos para este día.',
                          style: AppTextStyles.bodySm
                              .copyWith(color: AppColors.neutral700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: _saving ? null : _resetEditor,
                    icon: const Icon(Icons.add),
                    label: const Text('Agregar turno'),
                  ),
                ],
              ),
            ),
          if (selectedDuties.isNotEmpty) ...selectedDuties.map(_buildDutyItem),
        ],
      ),
    );
  }

  Widget _buildDutyItem(OwnerPharmacyDuty duty) {
    final label = '${_timeFormat.format(duty.startsAt)} - '
        '${_timeFormat.format(duty.endsAt)}';
    final statusLabel = switch (duty.status) {
      OwnerPharmacyDutyStatus.draft => 'Borrador',
      OwnerPharmacyDutyStatus.published => 'Publicado',
      OwnerPharmacyDutyStatus.cancelled => 'Cancelado',
    };

    final badgeColor = switch (duty.status) {
      OwnerPharmacyDutyStatus.draft => AppColors.tertiary500,
      OwnerPharmacyDutyStatus.published => AppColors.errorFg,
      OwnerPharmacyDutyStatus.cancelled => AppColors.neutral500,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.neutral50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: AppTextStyles.labelMd)),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  statusLabel,
                  style: AppTextStyles.bodyXs.copyWith(color: badgeColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: _saving ? null : () => _startEditing(duty),
                child: const Text('Editar'),
              ),
              if (duty.status == OwnerPharmacyDutyStatus.draft)
                TextButton(
                  onPressed: _saving
                      ? null
                      : () => _changeStatus(
                            duty,
                            OwnerPharmacyDutyStatus.published,
                          ),
                  child: const Text('Publicar'),
                ),
              if (duty.status == OwnerPharmacyDutyStatus.published)
                TextButton(
                  onPressed: _saving
                      ? null
                      : () => _changeStatus(
                            duty,
                            OwnerPharmacyDutyStatus.draft,
                          ),
                  child: const Text('Pasar a borrador'),
                ),
              if (duty.status != OwnerPharmacyDutyStatus.cancelled)
                TextButton(
                  onPressed: _saving
                      ? null
                      : () => _changeStatus(
                            duty,
                            OwnerPharmacyDutyStatus.cancelled,
                          ),
                  child: const Text('Cancelar'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEditorCard({
    required String merchantId,
    required String selectedDateKey,
  }) {
    final isEditing = _editingDutyId != null;
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
          Text(
            isEditing ? 'Editar turno' : 'Agregar turno',
            style: AppTextStyles.headingSm,
          ),
          const SizedBox(height: 10),
          Text(
            'Fecha: $selectedDateKey',
            style: AppTextStyles.bodySm.copyWith(color: AppColors.neutral700),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _timeField(
                  label: 'Inicio',
                  value: _startsAt.format(context),
                  onTap: _pickStartsAt,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _timeField(
                  label: 'Fin',
                  value: _endsAt.format(context),
                  onTap: _pickEndsAt,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<OwnerPharmacyDutyStatus>(
            initialValue: _draftStatus,
            items: const [
              DropdownMenuItem(
                value: OwnerPharmacyDutyStatus.draft,
                child: Text('Borrador'),
              ),
              DropdownMenuItem(
                value: OwnerPharmacyDutyStatus.published,
                child: Text('Publicado'),
              ),
            ],
            onChanged: _saving
                ? null
                : (value) {
                    if (value == null) return;
                    setState(() => _draftStatus = value);
                  },
            decoration: InputDecoration(
              labelText: 'Estado',
              filled: true,
              fillColor: AppColors.neutral50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _buildPreviewCard(selectedDateKey),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving
                  ? null
                  : () => _saveDuty(
                        merchantId: merchantId,
                        selectedDateKey: selectedDateKey,
                      ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary500,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(_saving
                  ? 'Guardando...'
                  : isEditing
                      ? 'Guardar cambios'
                      : 'Guardar turno'),
            ),
          ),
          if (isEditing)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _saving ? null : _resetEditor,
                child: const Text('Cancelar edición'),
              ),
            ),
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

  Widget _buildPreviewCard(String selectedDateKey) {
    final endLabel = _endsAt.format(context);
    final startsLabel = _startsAt.format(context);
    final overnight = (_endsAt.hour * 60 + _endsAt.minute) <=
        (_startsAt.hour * 60 + _startsAt.minute);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.neutral100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: AppColors.primary600,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Text(
              'Así lo verá el vecino',
              style: AppTextStyles.labelMd.copyWith(color: Colors.white),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.errorFg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'GUARDIA',
                    style: AppTextStyles.bodyXs.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  selectedDateKey,
                  style: AppTextStyles.labelMd,
                ),
                const SizedBox(height: 4),
                Text(
                  '$startsLabel - $endLabel${overnight ? ' (+1)' : ''}',
                  style: AppTextStyles.headingSm,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConflictCard(OwnerDutyConflict conflict) {
    final hasTimes = conflict.startsAtMillis > 0 && conflict.endsAtMillis > 0;
    final starts = hasTimes
        ? DateTime.fromMillisecondsSinceEpoch(conflict.startsAtMillis)
        : null;
    final ends = hasTimes
        ? DateTime.fromMillisecondsSinceEpoch(conflict.endsAtMillis)
        : null;
    final label = hasTimes
        ? '${_timeFormat.format(starts!)} - ${_timeFormat.format(ends!)} (${conflict.date})'
        : conflict.date;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.errorBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.errorFg.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.errorFg),
              const SizedBox(width: 8),
              Text(
                'Hay un conflicto de horarios',
                style: AppTextStyles.labelMd.copyWith(color: AppColors.errorFg),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Se superpone con un turno publicado existente: $label',
            style: AppTextStyles.bodySm.copyWith(color: AppColors.errorFg),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackBanner() {
    final fg = _feedbackError ? AppColors.errorFg : AppColors.successFg;
    final bg = _feedbackError ? AppColors.errorBg : AppColors.successBg;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            _feedbackError ? Icons.error_outline : Icons.check_circle_outline,
            size: 18,
            color: fg,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _feedbackMessage!,
              style: AppTextStyles.bodySm.copyWith(color: fg),
            ),
          ),
        ],
      ),
    );
  }

  void _ensureMonthLoaded(String merchantId) {
    final key = '${merchantId}_${_focusedMonth.year}-${_focusedMonth.month}';
    if (_loadedKey == key || _loadingMonth) return;
    _loadedKey = key;
    Future.microtask(() => _loadMonth(merchantId));
  }

  Future<void> _loadMonth(String merchantId) async {
    setState(() {
      _loadingMonth = true;
      _feedbackMessage = null;
    });
    try {
      final repository = ref.read(ownerPharmacyDutiesRepositoryProvider);
      final duties = await repository.listMonthDuties(
        merchantId: merchantId,
        month: _focusedMonth,
      );
      if (!mounted) return;
      setState(() {
        _monthDuties = duties;
        _loadingMonth = false;
        _lastConflict = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingMonth = false;
        _feedbackError = true;
        _feedbackMessage = 'No pudimos cargar los turnos del mes.';
      });
    }
  }

  Future<void> _saveDuty({
    required String merchantId,
    required String selectedDateKey,
  }) async {
    final startMinutes = _startsAt.hour * 60 + _startsAt.minute;
    final endMinutes = _endsAt.hour * 60 + _endsAt.minute;
    final overnight = endMinutes <= startMinutes;

    setState(() => _saving = true);
    try {
      final repository = ref.read(ownerPharmacyDutiesRepositoryProvider);
      await repository.upsertDuty(
        merchantId: merchantId,
        dutyId: _editingDutyId,
        date: selectedDateKey,
        startsAtIso: _toIsoUtc3(selectedDateKey, _startsAt, dayOffset: 0),
        endsAtIso: _toIsoUtc3(
          selectedDateKey,
          _endsAt,
          dayOffset: overnight ? 1 : 0,
        ),
        status: _draftStatus,
        expectedUpdatedAtMillis: _editingExpectedUpdatedAt,
      );
      if (!mounted) return;
      _resetEditor();
      await _loadMonth(merchantId);
      if (!mounted) return;
      setState(() {
        _feedbackError = false;
        _feedbackMessage = _draftStatus == OwnerPharmacyDutyStatus.published
            ? 'Turno publicado correctamente.'
            : 'Turno guardado en borrador.';
        _lastConflict = null;
      });
      await _showSavedDialog(
        selectedDateKey,
        _draftStatus == OwnerPharmacyDutyStatus.published
            ? 'Turno publicado'
            : 'Turno guardado',
      );
    } on OwnerDutyException catch (error) {
      if (!mounted) return;
      setState(() {
        _feedbackError = true;
        _feedbackMessage = error.message;
        _lastConflict = error.conflict;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _feedbackError = true;
        _feedbackMessage = 'No pudimos guardar el turno. Revisá tu conexión.';
      });
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _changeStatus(
    OwnerPharmacyDuty duty,
    OwnerPharmacyDutyStatus nextStatus,
  ) async {
    final merchantId =
        ref.read(ownerMerchantProvider).value?.primaryMerchant?.id;
    if (merchantId == null) return;

    setState(() => _saving = true);
    try {
      final repository = ref.read(ownerPharmacyDutiesRepositoryProvider);
      await repository.changeDutyStatus(
        dutyId: duty.id,
        status: nextStatus,
        expectedUpdatedAtMillis: duty.updatedAt?.millisecondsSinceEpoch,
      );
      if (!mounted) return;
      await _loadMonth(merchantId);
      if (!mounted) return;
      setState(() {
        _feedbackError = false;
        _feedbackMessage = 'Estado de turno actualizado.';
        _lastConflict = null;
      });
    } on OwnerDutyException catch (error) {
      if (!mounted) return;
      setState(() {
        _feedbackError = true;
        _feedbackMessage = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _feedbackError = true;
        _feedbackMessage = 'No pudimos actualizar el estado del turno.';
      });
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _startEditing(OwnerPharmacyDuty duty) {
    setState(() {
      _editingDutyId = duty.id;
      _editingExpectedUpdatedAt = duty.updatedAt?.millisecondsSinceEpoch;
      _draftStatus = duty.status == OwnerPharmacyDutyStatus.cancelled
          ? OwnerPharmacyDutyStatus.draft
          : duty.status;
      _startsAt = TimeOfDay.fromDateTime(duty.startsAt.toLocal());
      _endsAt = TimeOfDay.fromDateTime(duty.endsAt.toLocal());
      final selected = _dateKeyToDate(duty.dateKey);
      _selectedDate = selected;
      _focusedMonth = DateTime(selected.year, selected.month);
    });
  }

  void _resetEditor() {
    setState(() {
      _editingDutyId = null;
      _editingExpectedUpdatedAt = null;
      _startsAt = const TimeOfDay(hour: 8, minute: 0);
      _endsAt = const TimeOfDay(hour: 20, minute: 0);
      _draftStatus = OwnerPharmacyDutyStatus.draft;
    });
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

  String _dateKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  DateTime _dateKeyToDate(String dateKey) {
    final chunks = dateKey.split('-');
    if (chunks.length != 3) return DateTime.now();
    final y = int.tryParse(chunks[0]) ?? DateTime.now().year;
    final m = int.tryParse(chunks[1]) ?? DateTime.now().month;
    final d = int.tryParse(chunks[2]) ?? DateTime.now().day;
    return DateTime(y, m, d);
  }

  String _toIsoUtc3(
    String dateKey,
    TimeOfDay time, {
    required int dayOffset,
  }) {
    final base = _dateKeyToDate(dateKey).add(Duration(days: dayOffset));
    final y = base.year.toString().padLeft(4, '0');
    final m = base.month.toString().padLeft(2, '0');
    final d = base.day.toString().padLeft(2, '0');
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    return '$y-$m-${d}T$hh:$mm:00-03:00';
  }

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  Future<void> _showSavedDialog(String selectedDateKey, String title) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    color: AppColors.successBg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: AppColors.successFg,
                    size: 34,
                  ),
                ),
                const SizedBox(height: 12),
                Text(title, style: AppTextStyles.headingSm),
                const SizedBox(height: 6),
                Text(
                  'Fecha: $selectedDateKey',
                  style: AppTextStyles.bodySm
                      .copyWith(color: AppColors.neutral700),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary500,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Volver al calendario'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
