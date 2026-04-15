import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/providers/feature_flags_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../duties/models/owner_pharmacy_duty.dart';
import '../duties/repositories/owner_pharmacy_duties_repository.dart';
import '../providers/owner_providers.dart';
import 'owner_pharmacy_duty_editor_screen.dart';

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
  OwnerPharmacyDutyStatus _draftStatus = OwnerPharmacyDutyStatus.scheduled;
  bool _multiSelectMode = false;
  final Set<String> _selectedBatchDates = <String>{};

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
                  if (_showRetrySavePanel()) _buildRetrySaveCard(),
                  Expanded(
                    child: Stack(
                      children: [
                        RefreshIndicator(
                          onRefresh: () => _loadMonth(merchant.id),
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                            children: [
                              _buildHeroCard(),
                              const SizedBox(height: 12),
                              _buildMonthSummaryCard(),
                              const SizedBox(height: 12),
                              _buildOperationalActionsCard(selectedDuties),
                              if (_monthDuties.isEmpty) ...[
                                const SizedBox(height: 12),
                                _buildEmptyMonthStateCard(),
                              ],
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
                              _multiSelectMode
                                  ? _buildEditorCard(
                                      merchantId: merchant.id,
                                      selectedDateKey: selectedDateKey,
                                    )
                                  : _buildSingleDutyEntryCard(
                                      selectedDateKey: selectedDateKey,
                                      selectedDuties: selectedDuties,
                                    ),
                            ],
                          ),
                        ),
                        if (_saving) _buildSavingOverlay(),
                      ],
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

  bool _showRetrySavePanel() {
    if (!_feedbackError) return false;
    final message = (_feedbackMessage ?? '').toLowerCase();
    return message.contains('revisá tu conexión') ||
        message.contains('no pudimos guardar');
  }

  Widget _buildRetrySaveCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.errorBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.errorFg.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No pudimos guardar el turno',
            style: AppTextStyles.labelMd.copyWith(color: AppColors.errorFg),
          ),
          const SizedBox(height: 4),
          Text(
            'Revisá tu conexión e intentá de nuevo.',
            style: AppTextStyles.bodySm.copyWith(color: AppColors.errorFg),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _saving ? null : _retrySaveForSelectedDate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary500,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.refresh),
                label: const Text('Intentar de nuevo'),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: _saving
                    ? null
                    : () => setState(() {
                          _feedbackMessage = null;
                        }),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Volver'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSavingOverlay() {
    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          color: AppColors.surface.withValues(alpha: 0.72),
          child: Center(
            child: Container(
              width: 260,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.neutral100),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: AppColors.primary500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Guardando turno...',
                    style: AppTextStyles.headingSm.copyWith(
                      color: AppColors.neutral900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Esto puede tardar unos segundos.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodySm
                        .copyWith(color: AppColors.neutral700),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
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

  Widget _buildMonthSummaryCard() {
    final nonCancelled = _monthDuties
        .where((duty) => duty.status != OwnerPharmacyDutyStatus.cancelled);
    final coveredDays = nonCancelled.map((duty) => duty.dateKey).toSet().length;
    final activeCount = nonCancelled.length;
    final cancelledCount = _monthDuties
        .where((duty) => duty.status == OwnerPharmacyDutyStatus.cancelled)
        .length;

    Widget tile({
      required IconData icon,
      required String label,
      required String value,
      required Color color,
    }) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.neutral100),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(height: 8),
              Text(value, style: AppTextStyles.headingSm),
              Text(
                label,
                style:
                    AppTextStyles.bodyXs.copyWith(color: AppColors.neutral700),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        tile(
          icon: Icons.calendar_month_outlined,
          label: 'Turnos del mes',
          value: '$activeCount',
          color: AppColors.primary500,
        ),
        const SizedBox(width: 10),
        tile(
          icon: Icons.health_and_safety_outlined,
          label: 'Días cubiertos',
          value: '$coveredDays',
          color: AppColors.secondary500,
        ),
        const SizedBox(width: 10),
        tile(
          icon: Icons.cancel_outlined,
          label: 'Cancelados',
          value: '$cancelledCount',
          color: AppColors.warningFg,
        ),
      ],
    );
  }

  Widget _buildEmptyMonthStateCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.local_pharmacy_outlined,
                  color: AppColors.primary600,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Todavía no cargaste guardias para este mes.',
                  style: AppTextStyles.labelMd
                      .copyWith(color: AppColors.neutral900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Cargá tu primer turno para aparecer en la vista pública de farmacias de turno.',
            style: AppTextStyles.bodySm.copyWith(color: AppColors.neutral700),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: _saving
                ? null
                : () {
                    setState(() {
                      _selectedDate = DateTime(
                        _focusedMonth.year,
                        _focusedMonth.month,
                        1,
                      );
                    });
                    _resetEditor();
                  },
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('Agregar primer turno'),
          ),
        ],
      ),
    );
  }

  Widget _buildOperationalActionsCard(List<OwnerPharmacyDuty> selectedDuties) {
    final selectedDuty =
        selectedDuties.isNotEmpty ? selectedDuties.first : null;
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
            'Operación de guardia',
            style: AppTextStyles.labelMd.copyWith(color: AppColors.neutral900),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () =>
                    context.push(AppRoutes.ownerPharmacyDutyUpcoming),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Confirmar próxima guardia'),
              ),
              OutlinedButton.icon(
                onPressed: selectedDuty == null
                    ? null
                    : () => context.push(
                          AppRoutes.ownerPharmacyDutyIncidentReportPath(
                            selectedDuty.id,
                          ),
                        ),
                icon: const Icon(Icons.warning_amber_rounded),
                label: const Text('Reportar incidente'),
              ),
              OutlinedButton.icon(
                onPressed: selectedDuty == null
                    ? null
                    : () => context.push(
                          AppRoutes.ownerPharmacyDutyTrackingPath(
                            selectedDuty.id,
                          ),
                        ),
                icon: const Icon(Icons.track_changes_outlined),
                label: const Text('Seguimiento cobertura'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.neutral50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.neutral100),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _multiSelectMode
                        ? 'Selección múltiple activa (${_selectedBatchDates.length})'
                        : 'Carga rápida mensual (múltiples días)',
                    style: AppTextStyles.bodySm,
                  ),
                ),
                Switch.adaptive(
                  value: _multiSelectMode,
                  onChanged: _saving
                      ? null
                      : (enabled) {
                          setState(() {
                            _multiSelectMode = enabled;
                            if (!enabled) {
                              _selectedBatchDates.clear();
                            }
                          });
                        },
                ),
              ],
            ),
          ),
          if (_multiSelectMode && _selectedBatchDates.isNotEmpty)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _saving
                    ? null
                    : () => setState(() => _selectedBatchDates.clear()),
                child: const Text('Limpiar selección'),
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
    int priority(OwnerPharmacyDutyStatus status) {
      switch (status) {
        case OwnerPharmacyDutyStatus.active:
          return 6;
        case OwnerPharmacyDutyStatus.reassigned:
          return 5;
        case OwnerPharmacyDutyStatus.replacementPending:
          return 4;
        case OwnerPharmacyDutyStatus.incidentReported:
          return 3;
        case OwnerPharmacyDutyStatus.scheduled:
          return 2;
        case OwnerPharmacyDutyStatus.cancelled:
          return 1;
      }
    }

    for (final duty in _monthDuties) {
      final existing = statusByDate[duty.dateKey];
      if (existing == null || priority(duty.status) > priority(existing)) {
        statusByDate[duty.dateKey] = duty.status;
      }
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
              final multiSelected = _selectedBatchDates.contains(dayKey);
              final status = statusByDate[dayKey];

              return InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  setState(() {
                    _selectedDate = dayDate;
                    if (_multiSelectMode) {
                      if (multiSelected) {
                        _selectedBatchDates.remove(dayKey);
                      } else {
                        _selectedBatchDates.add(dayKey);
                      }
                    }
                  });
                },
                child: Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: multiSelected
                        ? AppColors.errorBg
                        : selected
                            ? AppColors.primary50
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: multiSelected
                          ? AppColors.errorFg
                          : selected
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
      case OwnerPharmacyDutyStatus.active:
      case OwnerPharmacyDutyStatus.reassigned:
        color = AppColors.errorFg;
      case OwnerPharmacyDutyStatus.replacementPending:
      case OwnerPharmacyDutyStatus.incidentReported:
        color = AppColors.warningFg;
      case OwnerPharmacyDutyStatus.cancelled:
        color = AppColors.neutral500;
      case OwnerPharmacyDutyStatus.scheduled:
        color = AppColors.secondary500;
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
        item(AppColors.secondary500, 'Programado'),
        item(AppColors.warningFg, 'Incidente / cobertura'),
        item(AppColors.errorFg, 'Activo / reasignado'),
        if (_multiSelectMode) item(AppColors.errorFg, 'Selección múltiple'),
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
                    onPressed: _saving ? null : _openNewDutyForm,
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

  Widget _buildSingleDutyEntryCard({
    required String selectedDateKey,
    required List<OwnerPharmacyDuty> selectedDuties,
  }) {
    final editingDuty = selectedDuties.isNotEmpty ? selectedDuties.first : null;
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
            editingDuty == null ? 'Nuevo turno' : 'Editar turno',
            style: AppTextStyles.headingSm,
          ),
          const SizedBox(height: 8),
          Text(
            'Fecha: $selectedDateKey',
            style: AppTextStyles.bodySm.copyWith(color: AppColors.neutral700),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _saving
                  ? null
                  : editingDuty == null
                      ? _openNewDutyForm
                      : () => _openEditDutyForm(editingDuty),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary500,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: Icon(
                editingDuty == null ? Icons.add : Icons.edit_calendar_outlined,
              ),
              label: Text(
                editingDuty == null ? 'Crear turno' : 'Editar turno',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDutyItem(OwnerPharmacyDuty duty) {
    final label = '${_timeFormat.format(duty.startsAt)} - '
        '${_timeFormat.format(duty.endsAt)}';
    final statusLabel = switch (duty.status) {
      OwnerPharmacyDutyStatus.scheduled => 'Programado',
      OwnerPharmacyDutyStatus.active => 'Activo',
      OwnerPharmacyDutyStatus.incidentReported => 'Incidente reportado',
      OwnerPharmacyDutyStatus.replacementPending => 'Cobertura en curso',
      OwnerPharmacyDutyStatus.reassigned => 'Reasignado',
      OwnerPharmacyDutyStatus.cancelled => 'Cancelado',
    };

    final badgeColor = switch (duty.status) {
      OwnerPharmacyDutyStatus.scheduled => AppColors.secondary500,
      OwnerPharmacyDutyStatus.active => AppColors.errorFg,
      OwnerPharmacyDutyStatus.incidentReported => AppColors.warningFg,
      OwnerPharmacyDutyStatus.replacementPending => AppColors.warningFg,
      OwnerPharmacyDutyStatus.reassigned => AppColors.errorFg,
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
                onPressed: _saving ? null : () => _openEditDutyForm(duty),
                child: const Text('Editar'),
              ),
              if (duty.status == OwnerPharmacyDutyStatus.cancelled)
                TextButton(
                  onPressed: _saving
                      ? null
                      : () => _changeStatus(
                            duty,
                            OwnerPharmacyDutyStatus.scheduled,
                          ),
                  child: const Text('Reactivar'),
                ),
              if (duty.status != OwnerPharmacyDutyStatus.cancelled)
                TextButton(
                  onPressed: _saving ? null : () => _confirmCancelDuty(duty),
                  child: const Text('Eliminar turno'),
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
    final batchCount = _selectedBatchDates.length;
    final isBatchSave = _multiSelectMode && !isEditing && batchCount > 0;
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
            isEditing
                ? 'Editar turno'
                : isBatchSave
                    ? 'Carga múltiple de turnos'
                    : 'Agregar turno',
            style: AppTextStyles.headingSm,
          ),
          const SizedBox(height: 10),
          Text(
            isBatchSave
                ? 'Fechas seleccionadas: $batchCount'
                : 'Fecha: $selectedDateKey',
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
            items: const <DropdownMenuItem<OwnerPharmacyDutyStatus>>[
              DropdownMenuItem(
                value: OwnerPharmacyDutyStatus.scheduled,
                child: Text('Programado'),
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
                      : isBatchSave
                          ? 'Publicar $batchCount turnos'
                          : 'Guardar turno'),
            ),
          ),
          if (isEditing)
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: _saving ? null : _resetEditor,
                    child: const Text('Cancelar edición'),
                  ),
                  TextButton.icon(
                    onPressed: _saving
                        ? null
                        : () {
                            final duty = _findEditingDuty();
                            if (duty == null) return;
                            _confirmCancelDuty(duty);
                          },
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Eliminar turno'),
                  ),
                ],
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
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _saving
                    ? null
                    : () {
                        setState(() {
                          _selectedDate = _dateKeyToDate(conflict.date);
                        });
                      },
                icon: const Icon(Icons.edit_calendar_outlined),
                label: const Text('Editar horario'),
              ),
              TextButton.icon(
                onPressed: _saving
                    ? null
                    : () {
                        setState(() {
                          _lastConflict = null;
                        });
                      },
                icon: const Icon(Icons.arrow_back),
                label: const Text('Volver al calendario'),
              ),
            ],
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
    if (_multiSelectMode &&
        _editingDutyId == null &&
        _selectedBatchDates.isEmpty) {
      setState(() {
        _feedbackError = true;
        _feedbackMessage = 'Seleccioná al menos un día del calendario.';
      });
      return;
    }

    final startMinutes = _startsAt.hour * 60 + _startsAt.minute;
    final endMinutes = _endsAt.hour * 60 + _endsAt.minute;
    final overnight = endMinutes <= startMinutes;
    final shouldBatchSave = _multiSelectMode &&
        _editingDutyId == null &&
        _selectedBatchDates.isNotEmpty;

    setState(() => _saving = true);
    try {
      final repository = ref.read(ownerPharmacyDutiesRepositoryProvider);
      if (shouldBatchSave) {
        final orderedDates = _selectedBatchDates.toList(growable: false)
          ..sort();
        final batchRows = orderedDates
            .map((dateKey) => (
                  date: dateKey,
                  startsAtIso: _toIsoUtc3(dateKey, _startsAt, dayOffset: 0),
                  endsAtIso: _toIsoUtc3(
                    dateKey,
                    _endsAt,
                    dayOffset: overnight ? 1 : 0,
                  ),
                  status: _draftStatus,
                  notes: null,
                ))
            .toList(growable: false);
        final result = await repository.upsertDutiesBatch(
          merchantId: merchantId,
          duties: batchRows,
        );
        if (!mounted) return;
        await _loadMonth(merchantId);
        if (!mounted) return;
        setState(() {
          _feedbackError = false;
          _feedbackMessage =
              'Turnos procesados: ${result.acceptedRows} (${result.createdRows} nuevos, ${result.updatedRows} actualizados, ${result.unchangedRows} sin cambios).';
          _lastConflict = null;
          _selectedBatchDates.clear();
        });
        await _showSavedDialog(
          '${result.acceptedRows} fechas',
          'Carga mensual completada',
        );
      } else {
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
          _feedbackMessage = 'Turno programado correctamente.';
          _lastConflict = null;
        });
        await _showSavedDialog(
          selectedDateKey,
          'Turno guardado',
        );
      }
      if (!mounted) return;
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

  Future<void> _retrySaveForSelectedDate() async {
    final merchantId =
        ref.read(ownerMerchantProvider).value?.primaryMerchant?.id;
    if (merchantId == null) return;
    await _saveDuty(
      merchantId: merchantId,
      selectedDateKey: _dateKey(_selectedDate),
    );
  }

  Future<void> _openNewDutyForm() async {
    final result = await context.push<bool>(
      AppRoutes.ownerPharmacyDutyNewPath(date: _dateKey(_selectedDate)),
    );
    if (result != true) return;
    final merchantId =
        ref.read(ownerMerchantProvider).value?.primaryMerchant?.id;
    if (merchantId == null) return;
    await _loadMonth(merchantId);
  }

  Future<void> _openEditDutyForm(OwnerPharmacyDuty duty) async {
    final result = await context.push<bool>(
      AppRoutes.ownerPharmacyDutyEditPath(duty.id),
      extra: OwnerPharmacyDutyEditorExtra(duty: duty),
    );
    if (result != true) return;
    final merchantId =
        ref.read(ownerMerchantProvider).value?.primaryMerchant?.id;
    if (merchantId == null) return;
    await _loadMonth(merchantId);
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

  Future<void> _confirmCancelDuty(OwnerPharmacyDuty duty) async {
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
    await _changeStatus(duty, OwnerPharmacyDutyStatus.cancelled);
  }

  OwnerPharmacyDuty? _findEditingDuty() {
    final editingId = _editingDutyId;
    if (editingId == null || editingId.isEmpty) return null;
    for (final duty in _monthDuties) {
      if (duty.id == editingId) return duty;
    }
    return null;
  }

  void _resetEditor() {
    setState(() {
      _editingDutyId = null;
      _editingExpectedUpdatedAt = null;
      _startsAt = const TimeOfDay(hour: 8, minute: 0);
      _endsAt = const TimeOfDay(hour: 20, minute: 0);
      _draftStatus = OwnerPharmacyDutyStatus.scheduled;
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
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _resetEditor();
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.neutral300),
                    ),
                    child: const Text('Cargar otro turno'),
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
