import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/auth_providers.dart';
import '../../../core/providers/feature_flags_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../analytics/owner_schedule_analytics.dart';
import '../schedules/owner_schedule_models.dart';
import '../schedules/owner_schedule_repository.dart';
import '../schedules/owner_schedule_utils.dart';

class OwnerScheduleScreen extends ConsumerStatefulWidget {
  const OwnerScheduleScreen({super.key});

  @override
  ConsumerState<OwnerScheduleScreen> createState() =>
      _OwnerScheduleScreenState();
}

class _OwnerScheduleScreenState extends ConsumerState<OwnerScheduleScreen> {
  final _repository = OwnerScheduleRepository();

  bool _isInitialLoading = false;
  bool _isSaving = false;
  bool _weeklyEditorEnabled = false;
  bool _hasUnsavedChanges = false;
  bool _viewLogged = false;

  String? _loadedMerchantId;
  int _version = 0;
  String _timezone = 'America/Argentina/Buenos_Aires';

  List<DayScheduleDraft> _weeklyDraft = _defaultWeeklyClosed();
  List<ScheduleExceptionDraft> _exceptions = const [];
  List<TemporaryClosureDraft> _temporaryClosures = const [];

  Set<String> _deletedExceptionIds = <String>{};
  Set<String> _deletedClosureIds = <String>{};

  String? _feedbackMessage;
  bool _feedbackIsError = false;

  @override
  Widget build(BuildContext context) {
    final merchantIdAsync = ref.watch(ownerMerchantIdProvider);
    final scheduleFeatureEnabledAsync =
        ref.watch(ownerScheduleEditorEnabledProvider);
    final user = ref.watch(currentUserProvider);

    return scheduleFeatureEnabledAsync.when(
      loading: () => _buildLoadingScaffold(),
      error: (_, __) =>
          _buildErrorScaffold('No se pudo consultar el feature flag.'),
      data: (isFeatureEnabled) {
        if (!isFeatureEnabled) {
          return _buildFeatureDisabledScaffold();
        }
        return merchantIdAsync.when(
          loading: () => _buildLoadingScaffold(),
          error: (_, __) =>
              _buildErrorScaffold('No se pudo cargar tu comercio.'),
          data: (merchantId) {
            if (merchantId == null) {
              return _buildErrorScaffold(
                'No encontramos un comercio asociado a tu usuario.',
              );
            }
            _ensureLoaded(merchantId);
            return PopScope(
              canPop: !_hasUnsavedChanges,
              onPopInvokedWithResult: (didPop, _) async {
                if (didPop) return;
                final canLeave = await _onWillPop();
                if (canLeave && context.mounted) {
                  context.pop();
                }
              },
              child: Scaffold(
                backgroundColor: AppColors.scaffoldBg,
                appBar: AppBar(
                  backgroundColor: AppColors.surface,
                  elevation: 0,
                  leading: IconButton(
                    onPressed: _handleBackPress,
                    icon: const Icon(Icons.arrow_back),
                    color: AppColors.primary500,
                  ),
                  title: const Text('Horarios', style: AppTextStyles.headingSm),
                  actions: [
                    IconButton(
                      onPressed: () => _showHelp(context),
                      icon: const Icon(Icons.help_outline),
                    ),
                  ],
                ),
                body: _isInitialLoading
                    ? const Center(child: CircularProgressIndicator())
                    : Column(
                        children: [
                          if (_feedbackMessage != null) _buildFeedbackBanner(),
                          Expanded(
                            child: SingleChildScrollView(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 16, 16, 220),
                              child: _weeklyEditorEnabled
                                  ? _buildFullEditor(context)
                                  : _buildInitialEmptyState(context),
                            ),
                          ),
                        ],
                      ),
                bottomSheet: _weeklyEditorEnabled
                    ? _buildBottomSaveBar(
                        onSave: () => _onSavePressed(
                          merchantId: merchantId,
                          uid: user?.uid,
                        ),
                      )
                    : null,
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
        title: const Text('Horarios', style: AppTextStyles.headingSm),
      ),
      body: const Center(child: CircularProgressIndicator()),
    );
  }

  Scaffold _buildErrorScaffold(String message) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        title: const Text('Horarios', style: AppTextStyles.headingSm),
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

  Scaffold _buildFeatureDisabledScaffold() {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        title: const Text('Horarios', style: AppTextStyles.headingSm),
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.toggle_off_outlined,
                size: 44,
                color: AppColors.neutral600,
              ),
              SizedBox(height: 12),
              Text(
                'El editor de horarios está deshabilitado temporalmente.',
                style: AppTextStyles.bodyMd,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeedbackBanner() {
    final fg = _feedbackIsError ? AppColors.errorFg : AppColors.successFg;
    final bg = _feedbackIsError ? AppColors.errorBg : AppColors.successBg;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            _feedbackIsError ? Icons.error_outline : Icons.check_circle,
            color: fg,
            size: 18,
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

  Widget _buildInitialEmptyState(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.neutral100),
          ),
          child: Column(
            children: [
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  color: AppColors.primary50,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.calendar_today,
                  color: AppColors.primary500,
                  size: 42,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Horarios de atención',
                style: AppTextStyles.headingMd,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Todavía no cargaste tus horarios.',
                style:
                    AppTextStyles.bodyMd.copyWith(color: AppColors.neutral700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _weeklyEditorEnabled = true;
                      _feedbackMessage = null;
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary500,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  icon: const Icon(Icons.settings),
                  label: const Text('Configurar horarios'),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Tus vecinos verán este horario en el perfil público.',
                style: AppTextStyles.bodyXs,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFullEditor(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Definí cuándo está abierto tu comercio',
          style: AppTextStyles.bodyMd.copyWith(color: AppColors.neutral700),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _applyWeekdaysContinuousTemplate,
          style: OutlinedButton.styleFrom(
            backgroundColor: AppColors.secondary50,
            foregroundColor: AppColors.secondary600,
            side: BorderSide.none,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          icon: const Icon(Icons.auto_awesome, size: 18),
          label: const Text('Aplicar a lunes a viernes'),
        ),
        const SizedBox(height: 18),
        ..._weeklyDraft.map(_buildDayCard),
        const SizedBox(height: 22),
        _buildExceptionsSection(context),
      ],
    );
  }

  Widget _buildDayCard(DayScheduleDraft day) {
    final validation = validateDaySchedule(day);
    final isError = validation != null;
    final badgeColor = switch (day.mode) {
      DayScheduleMode.closed => AppColors.neutral300,
      DayScheduleMode.continuous => AppColors.secondary100,
      DayScheduleMode.split => AppColors.primary100,
    };
    final badgeTextColor = switch (day.mode) {
      DayScheduleMode.closed => AppColors.neutral700,
      DayScheduleMode.continuous => AppColors.secondary700,
      DayScheduleMode.split => AppColors.primary700,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isError
              ? AppColors.errorFg.withValues(alpha: .22)
              : AppColors.neutral100,
          width: isError ? 1.4 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(day.dayLabel, style: AppTextStyles.headingSm),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  modeLabel(day.mode),
                  style: AppTextStyles.bodyXs.copyWith(
                    color: badgeTextColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildModeChoice(day, DayScheduleMode.closed, 'Cerrado'),
              _buildModeChoice(
                  day, DayScheduleMode.continuous, 'Horario corrido'),
              _buildModeChoice(day, DayScheduleMode.split, 'Horario cortado'),
            ],
          ),
          if (day.mode != DayScheduleMode.closed) ...[
            const SizedBox(height: 12),
            _buildTimeRow(
              startLabel: day.mode == DayScheduleMode.split
                  ? 'Apertura mañana'
                  : 'Apertura',
              endLabel: day.mode == DayScheduleMode.split
                  ? 'Cierre mañana'
                  : 'Cierre',
              start: day.firstOpen,
              end: day.firstClose,
              onStartTap: () => _pickTimeForDay(day, true, false),
              onEndTap: () => _pickTimeForDay(day, false, false),
            ),
          ],
          if (day.mode == DayScheduleMode.split) ...[
            const SizedBox(height: 10),
            _buildTimeRow(
              startLabel: 'Apertura tarde',
              endLabel: 'Cierre tarde',
              start: day.secondOpen,
              end: day.secondClose,
              onStartTap: () => _pickTimeForDay(day, true, true),
              onEndTap: () => _pickTimeForDay(day, false, true),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            'Se verá como: ${daySummary(day)}',
            style: AppTextStyles.bodyXs.copyWith(color: AppColors.secondary600),
          ),
          if (validation != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.error_outline,
                    size: 16, color: AppColors.errorFg),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    validation,
                    style:
                        AppTextStyles.bodySm.copyWith(color: AppColors.errorFg),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildModeChoice(
    DayScheduleDraft day,
    DayScheduleMode mode,
    String label,
  ) {
    final selected = day.mode == mode;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: AppColors.primary100,
      labelStyle: AppTextStyles.labelSm.copyWith(
        color: selected ? AppColors.primary700 : AppColors.neutral700,
      ),
      side: BorderSide(
        color: selected ? AppColors.primary300 : AppColors.neutral200,
      ),
      onSelected: (_) => _updateDayMode(day.dayKey, mode),
    );
  }

  Widget _buildTimeRow({
    required String startLabel,
    required String endLabel,
    required String? start,
    required String? end,
    required VoidCallback onStartTap,
    required VoidCallback onEndTap,
  }) {
    return Row(
      children: [
        Expanded(
          child: _buildTimeField(
            label: startLabel,
            value: start,
            onTap: onStartTap,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildTimeField(
            label: endLabel,
            value: end,
            onTap: onEndTap,
          ),
        ),
      ],
    );
  }

  Widget _buildTimeField({
    required String label,
    required String? value,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: AppTextStyles.bodyXs.copyWith(color: AppColors.neutral600)),
        const SizedBox(height: 4),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.neutral50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.neutral200),
            ),
            child: Row(
              children: [
                Text(
                  value ?? '--:--',
                  style: AppTextStyles.labelMd.copyWith(
                    color: value == null
                        ? AppColors.neutral500
                        : AppColors.neutral900,
                  ),
                ),
                const Spacer(),
                const Icon(
                  Icons.schedule,
                  size: 16,
                  color: AppColors.primary500,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExceptionsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Cierres temporales y feriados', style: AppTextStyles.headingMd),
        const SizedBox(height: 6),
        Text(
          'Agregalo acá para avisar a tus vecinos.',
          style: AppTextStyles.bodySm.copyWith(color: AppColors.neutral700),
        ),
        const SizedBox(height: 12),
        if (_exceptions.isEmpty && _temporaryClosures.isEmpty)
          _buildEmptyExceptionsState(context)
        else ...[
          ..._exceptions.map(_buildExceptionCard),
          ..._temporaryClosures.map(_buildTemporaryClosureCard),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _openAddMenu,
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Cargar nuevo feriado o cierre'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEmptyExceptionsState(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.neutral100),
      ),
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: AppColors.primary50,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.event_busy, color: AppColors.primary500),
          ),
          const SizedBox(height: 10),
          const Text(
            'Sin cierres cargados',
            style: AppTextStyles.headingSm,
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _addTemporaryClosure,
              icon: const Icon(Icons.add_circle),
              label: const Text('Agregar cierre temporal'),
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _addSpecialDate,
            icon: const Icon(Icons.event),
            label: const Text('Agregar fecha especial'),
          ),
        ],
      ),
    );
  }

  Widget _buildExceptionCard(ScheduleExceptionDraft exception) {
    final isClosed = exception.type == ScheduleExceptionType.closed;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.neutral100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isClosed ? AppColors.errorBg : AppColors.primary50,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  isClosed ? 'Feriado' : 'Especial',
                  style: AppTextStyles.bodyXs.copyWith(
                    color: isClosed ? AppColors.errorFg : AppColors.primary700,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => _editException(exception),
                icon: const Icon(Icons.edit_outlined, size: 19),
              ),
              IconButton(
                onPressed: () => _removeException(exception),
                icon: const Icon(Icons.delete_outline, size: 19),
              ),
            ],
          ),
          Text(
            formatDateLong(exception.date),
            style: AppTextStyles.headingSm,
          ),
          const SizedBox(height: 3),
          Text(
            exceptionSummary(exception),
            style: AppTextStyles.bodySm,
          ),
        ],
      ),
    );
  }

  Widget _buildTemporaryClosureCard(TemporaryClosureDraft closure) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary500,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .2),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Cierre temporal',
                  style: AppTextStyles.bodyXs.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => _editTemporaryClosure(closure),
                color: Colors.white,
                icon: const Icon(Icons.edit_outlined, size: 19),
              ),
              IconButton(
                onPressed: () => _removeTemporaryClosure(closure),
                color: Colors.white,
                icon: const Icon(Icons.delete_outline, size: 19),
              ),
            ],
          ),
          Text(
            closure.reason?.trim().isNotEmpty == true
                ? closure.reason!
                : 'Cierre temporal',
            style: AppTextStyles.headingSm.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 3),
          Text(
            formatDateRange(closure.startDate, closure.endDate),
            style: AppTextStyles.bodySm.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSaveBar({
    required VoidCallback onSave,
  }) {
    final preview = buildTodayPreview(
      now: DateTime.now(),
      weekly: _weeklyDraft,
      exceptions: _exceptions,
      closures: _temporaryClosures,
    );
    final hasErrors = _hasValidationErrors;
    final canTap = !_isSaving;
    return Container(
      width: double.infinity,
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.secondary50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.visibility,
                      size: 18, color: AppColors.secondary600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      preview,
                      style: AppTextStyles.bodySm.copyWith(
                        color: AppColors.secondary700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: canTap ? onSave : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      hasErrors ? AppColors.neutral300 : AppColors.primary500,
                  foregroundColor: Colors.white,
                  disabledForegroundColor: AppColors.neutral600,
                  disabledBackgroundColor: AppColors.neutral300,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        hasErrors
                            ? 'Corregí errores para guardar'
                            : 'Guardar horarios',
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _ensureLoaded(String merchantId) async {
    if (_loadedMerchantId == merchantId || _isInitialLoading) return;
    setState(() {
      _isInitialLoading = true;
      _feedbackMessage = null;
      _feedbackIsError = false;
    });
    try {
      final bundle = await _repository.fetchSchedule(merchantId);
      if (!mounted) return;
      if (!_viewLogged) {
        unawaited(OwnerScheduleAnalytics.logScreenView());
        _viewLogged = true;
      }
      final hasWeekly =
          bundle.weekly.any((day) => day.mode != DayScheduleMode.closed);
      setState(() {
        _loadedMerchantId = merchantId;
        _weeklyDraft = bundle.weekly;
        _exceptions = bundle.exceptions;
        _temporaryClosures = bundle.temporaryClosures;
        _version = bundle.version;
        _timezone = bundle.timezone;
        _weeklyEditorEnabled = hasWeekly ||
            bundle.exceptions.isNotEmpty ||
            bundle.temporaryClosures.isNotEmpty;
        _hasUnsavedChanges = false;
        _deletedExceptionIds = <String>{};
        _deletedClosureIds = <String>{};
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _feedbackIsError = true;
        _feedbackMessage = 'No se pudieron cargar los horarios.';
      });
    } finally {
      if (mounted) {
        setState(() => _isInitialLoading = false);
      }
    }
  }

  bool get _hasValidationErrors {
    if (_weeklyDraft.any((day) => validateDaySchedule(day) != null)) {
      return true;
    }
    if (_exceptions.any((exception) => validateException(exception) != null)) {
      return true;
    }
    if (_temporaryClosures
        .any((closure) => validateTemporaryClosure(closure) != null)) {
      return true;
    }
    return false;
  }

  ({int weekly, int exception, int closure}) get _validationCounts {
    final weekly =
        _weeklyDraft.where((day) => validateDaySchedule(day) != null).length;
    final exception =
        _exceptions.where((item) => validateException(item) != null).length;
    final closure = _temporaryClosures
        .where((item) => validateTemporaryClosure(item) != null)
        .length;
    return (weekly: weekly, exception: exception, closure: closure);
  }

  Future<void> _pickTimeForDay(
    DayScheduleDraft day,
    bool isStart,
    bool secondBlock,
  ) async {
    final currentValue = secondBlock
        ? (isStart ? day.secondOpen : day.secondClose)
        : (isStart ? day.firstOpen : day.firstClose);
    final initial =
        _timeOfDayFromHHmm(currentValue) ?? const TimeOfDay(hour: 9, minute: 0);
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    final hhmm = _hhmmFromTimeOfDay(picked);
    setState(() {
      _hasUnsavedChanges = true;
      _feedbackMessage = null;
      _weeklyDraft = _weeklyDraft.map((item) {
        if (item.dayKey != day.dayKey) return item;
        if (secondBlock) {
          return isStart
              ? item.copyWith(secondOpen: hhmm)
              : item.copyWith(secondClose: hhmm);
        }
        return isStart
            ? item.copyWith(firstOpen: hhmm)
            : item.copyWith(firstClose: hhmm);
      }).toList(growable: false);
    });
  }

  void _updateDayMode(String dayKey, DayScheduleMode mode) {
    unawaited(OwnerScheduleAnalytics.logModeSelected(
      dayKey: dayKey,
      mode: dayModeToString(mode),
    ));
    setState(() {
      _feedbackMessage = null;
      _hasUnsavedChanges = true;
      _weeklyDraft = _weeklyDraft.map((day) {
        if (day.dayKey != dayKey) return day;
        switch (mode) {
          case DayScheduleMode.closed:
            return day.copyWith(
              mode: mode,
              clearFirstOpen: true,
              clearFirstClose: true,
              clearSecondOpen: true,
              clearSecondClose: true,
            );
          case DayScheduleMode.continuous:
            return day.copyWith(
              mode: mode,
              secondOpen: null,
              secondClose: null,
              clearSecondOpen: true,
              clearSecondClose: true,
              firstOpen: day.firstOpen ?? '08:00',
              firstClose: day.firstClose ?? '20:00',
            );
          case DayScheduleMode.split:
            return day.copyWith(
              mode: mode,
              firstOpen: day.firstOpen ?? '08:00',
              firstClose: day.firstClose ?? '12:00',
              secondOpen: day.secondOpen ?? '16:00',
              secondClose: day.secondClose ?? '20:00',
            );
        }
      }).toList(growable: false);
    });
  }

  Future<void> _addSpecialDate() async {
    final created = await _showExceptionSheet();
    if (created == null) return;
    unawaited(OwnerScheduleAnalytics.logAddException(
      exceptionKind: 'special_date',
    ));
    setState(() {
      _hasUnsavedChanges = true;
      _feedbackMessage = null;
      // Si se recrea una excepción con una fecha previamente eliminada
      // en este draft, no debe persistirse su borrado al guardar.
      _deletedExceptionIds.remove(created.id);
      _exceptions = [
        ..._exceptions.where((item) => item.id != created.id),
        created
      ]..sort((a, b) => a.date.compareTo(b.date));
    });
  }

  Future<void> _editException(ScheduleExceptionDraft exception) async {
    final updated = await _showExceptionSheet(initial: exception);
    if (updated == null) return;
    setState(() {
      _hasUnsavedChanges = true;
      _feedbackMessage = null;
      if (updated.id != exception.id) {
        // Si cambió la fecha (doc id), borrar el documento previo al guardar.
        _deletedExceptionIds.add(exception.id);
      }
      _deletedExceptionIds.remove(updated.id);
      _exceptions = _exceptions
          .map((item) => item.id == exception.id ? updated : item)
          .toList(growable: false)
        ..sort((a, b) => a.date.compareTo(b.date));
    });
  }

  void _removeException(ScheduleExceptionDraft exception) {
    setState(() {
      _hasUnsavedChanges = true;
      _deletedExceptionIds.add(exception.id);
      _exceptions = _exceptions
          .where((item) => item.id != exception.id)
          .toList(growable: false);
    });
  }

  Future<void> _addTemporaryClosure() async {
    final created = await _showTemporaryClosureSheet();
    if (created == null) return;
    unawaited(OwnerScheduleAnalytics.logAddException(
      exceptionKind: 'temporary_closure',
    ));
    setState(() {
      _hasUnsavedChanges = true;
      _feedbackMessage = null;
      _temporaryClosures = [..._temporaryClosures, created]
        ..sort((a, b) => a.startDate.compareTo(b.startDate));
    });
  }

  Future<void> _editTemporaryClosure(TemporaryClosureDraft closure) async {
    final updated = await _showTemporaryClosureSheet(initial: closure);
    if (updated == null) return;
    setState(() {
      _hasUnsavedChanges = true;
      _feedbackMessage = null;
      _temporaryClosures = _temporaryClosures
          .map((item) => item.id == closure.id ? updated : item)
          .toList(growable: false)
        ..sort((a, b) => a.startDate.compareTo(b.startDate));
    });
  }

  void _removeTemporaryClosure(TemporaryClosureDraft closure) {
    setState(() {
      _hasUnsavedChanges = true;
      _deletedClosureIds.add(closure.id);
      _temporaryClosures = _temporaryClosures
          .where((item) => item.id != closure.id)
          .toList(growable: false);
    });
  }

  Future<void> _saveAll({
    required String merchantId,
    required String? uid,
  }) async {
    if (uid == null || _isSaving || _hasValidationErrors) return;
    setState(() {
      _isSaving = true;
      _feedbackMessage = null;
    });
    try {
      await _repository.saveSchedule(
        merchantId: merchantId,
        uid: uid,
        payload: OwnerScheduleSavePayload(
          weekly: _weeklyDraft,
          exceptions: _exceptions,
          temporaryClosures: _temporaryClosures,
          deletedExceptionIds: _deletedExceptionIds,
          deletedClosureIds: _deletedClosureIds,
          currentVersion: _version,
          timezone: _timezone,
        ),
      );
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _hasUnsavedChanges = false;
        _version = _version + 1;
        _deletedExceptionIds = <String>{};
        _deletedClosureIds = <String>{};
        _feedbackIsError = false;
        _feedbackMessage = 'Horarios guardados.';
      });
      unawaited(OwnerScheduleAnalytics.logSaveSuccess());
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _feedbackIsError = true;
        _feedbackMessage = 'No se pudo guardar. Revisá tu conexión.';
      });
      unawaited(
          OwnerScheduleAnalytics.logSaveError(reason: 'network_or_write'));
    }
  }

  Future<void> _onSavePressed({
    required String merchantId,
    required String? uid,
  }) async {
    if (_isSaving) return;
    if (_hasValidationErrors) {
      final counts = _validationCounts;
      unawaited(OwnerScheduleAnalytics.logValidationError(
        weeklyErrors: counts.weekly,
        exceptionErrors: counts.exception,
        closureErrors: counts.closure,
      ));
      setState(() {
        _feedbackIsError = true;
        _feedbackMessage = 'Revisá los horarios marcados en rojo.';
      });
      return;
    }
    await _saveAll(merchantId: merchantId, uid: uid);
  }

  void _applyWeekdaysContinuousTemplate() {
    unawaited(OwnerScheduleAnalytics.logApplyWeekdaysTemplate());
    setState(() {
      _hasUnsavedChanges = true;
      _feedbackMessage = null;
      _weeklyDraft = _weeklyDraft.map((day) {
        if (day.dayKey == 'saturday' || day.dayKey == 'sunday') return day;
        return day.copyWith(
          mode: DayScheduleMode.continuous,
          firstOpen: '08:00',
          firstClose: '20:00',
          clearSecondOpen: true,
          clearSecondClose: true,
        );
      }).toList(growable: false);
    });
  }

  Future<void> _openAddMenu() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.event_available),
              title: const Text('Agregar fecha especial'),
              onTap: () => Navigator.of(context).pop('special'),
            ),
            ListTile(
              leading: const Icon(Icons.beach_access),
              title: const Text('Agregar cierre temporal'),
              onTap: () => Navigator.of(context).pop('closure'),
            ),
          ],
        ),
      ),
    );
    if (selected == 'special') {
      unawaited(_addSpecialDate());
    } else if (selected == 'closure') {
      unawaited(_addTemporaryClosure());
    }
  }

  Future<ScheduleExceptionDraft?> _showExceptionSheet({
    ScheduleExceptionDraft? initial,
  }) async {
    return showModalBottomSheet<ScheduleExceptionDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        var draft = initial ??
            ScheduleExceptionDraft(
              id: DateFormat('yyyy-MM-dd').format(DateTime.now()),
              date: DateTime.now(),
              type: ScheduleExceptionType.closed,
              mode: DayScheduleMode.closed,
            );
        String? formError;
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> pickDate() async {
              final picked = await showDatePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
                initialDate: draft.date,
              );
              if (picked == null) return;
              setModalState(() {
                final id = DateFormat('yyyy-MM-dd').format(picked);
                draft = draft.copyWith(date: picked).copyWith(
                      firstOpen: draft.firstOpen,
                    );
                draft = ScheduleExceptionDraft(
                  id: id,
                  date: draft.date,
                  type: draft.type,
                  mode: draft.mode,
                  reason: draft.reason,
                  firstOpen: draft.firstOpen,
                  firstClose: draft.firstClose,
                  secondOpen: draft.secondOpen,
                  secondClose: draft.secondClose,
                );
              });
            }

            Future<void> pickTime(bool isStart, bool secondBlock) async {
              final current = secondBlock
                  ? (isStart ? draft.secondOpen : draft.secondClose)
                  : (isStart ? draft.firstOpen : draft.firstClose);
              final picked = await showTimePicker(
                context: context,
                initialTime: _timeOfDayFromHHmm(current) ??
                    const TimeOfDay(hour: 9, minute: 0),
              );
              if (picked == null) return;
              final hhmm = _hhmmFromTimeOfDay(picked);
              setModalState(() {
                if (secondBlock) {
                  draft = isStart
                      ? draft.copyWith(secondOpen: hhmm)
                      : draft.copyWith(secondClose: hhmm);
                } else {
                  draft = isStart
                      ? draft.copyWith(firstOpen: hhmm)
                      : draft.copyWith(firstClose: hhmm);
                }
              });
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 8,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    initial == null
                        ? 'Agregar fecha especial'
                        : 'Editar fecha especial',
                    style: AppTextStyles.headingMd,
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Fecha'),
                    subtitle: Text(formatDateLong(draft.date)),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: pickDate,
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<ScheduleExceptionType>(
                    segments: const [
                      ButtonSegment(
                        value: ScheduleExceptionType.closed,
                        label: Text('Cerrado'),
                        icon: Icon(Icons.block),
                      ),
                      ButtonSegment(
                        value: ScheduleExceptionType.specialHours,
                        label: Text('Horario especial'),
                        icon: Icon(Icons.schedule),
                      ),
                    ],
                    selected: {draft.type},
                    onSelectionChanged: (selection) {
                      final nextType = selection.first;
                      setModalState(() {
                        draft = draft.copyWith(
                          type: nextType,
                          mode: nextType == ScheduleExceptionType.closed
                              ? DayScheduleMode.closed
                              : DayScheduleMode.continuous,
                        );
                      });
                    },
                  ),
                  if (draft.type == ScheduleExceptionType.specialHours) ...[
                    const SizedBox(height: 10),
                    SegmentedButton<DayScheduleMode>(
                      segments: const [
                        ButtonSegment(
                          value: DayScheduleMode.continuous,
                          label: Text('Corrido'),
                        ),
                        ButtonSegment(
                          value: DayScheduleMode.split,
                          label: Text('Cortado'),
                        ),
                      ],
                      selected: {draft.mode},
                      onSelectionChanged: (selection) {
                        setModalState(() {
                          final mode = selection.first;
                          draft = draft.copyWith(mode: mode);
                          if (mode == DayScheduleMode.continuous) {
                            draft = draft.copyWith(
                              clearSecondOpen: true,
                              clearSecondClose: true,
                            );
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    _buildTimeRow(
                      startLabel: 'Desde',
                      endLabel: 'Hasta',
                      start: draft.firstOpen,
                      end: draft.firstClose,
                      onStartTap: () => pickTime(true, false),
                      onEndTap: () => pickTime(false, false),
                    ),
                    if (draft.mode == DayScheduleMode.split) ...[
                      const SizedBox(height: 10),
                      _buildTimeRow(
                        startLabel: 'Desde tarde',
                        endLabel: 'Hasta tarde',
                        start: draft.secondOpen,
                        end: draft.secondClose,
                        onStartTap: () => pickTime(true, true),
                        onEndTap: () => pickTime(false, true),
                      ),
                    ],
                  ],
                  const SizedBox(height: 8),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Motivo (opcional)',
                      hintText: 'Ej. Feriado, evento, horario especial',
                    ),
                    controller: TextEditingController(text: draft.reason)
                      ..selection = TextSelection.collapsed(
                        offset: (draft.reason ?? '').length,
                      ),
                    onChanged: (value) => draft = draft.copyWith(reason: value),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Se verá como: ${exceptionSummary(draft)}',
                    style: AppTextStyles.bodySm
                        .copyWith(color: AppColors.secondary700),
                  ),
                  if (formError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      formError!,
                      style: AppTextStyles.bodySm
                          .copyWith(color: AppColors.errorFg),
                    ),
                  ],
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        final validation = validateException(draft);
                        final duplicatedDate = _exceptions.any(
                          (item) =>
                              item.id == draft.id && item.id != initial?.id,
                        );
                        if (validation != null || duplicatedDate) {
                          setModalState(() {
                            formError = duplicatedDate
                                ? 'Ya existe una excepción para esta fecha.'
                                : validation;
                          });
                          return;
                        }
                        Navigator.of(context).pop(draft);
                      },
                      child: Text(
                        initial == null
                            ? 'Guardar fecha especial'
                            : 'Guardar cambios',
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<TemporaryClosureDraft?> _showTemporaryClosureSheet({
    TemporaryClosureDraft? initial,
  }) async {
    return showModalBottomSheet<TemporaryClosureDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        var draft = initial ??
            TemporaryClosureDraft(
              id: 'range_${DateTime.now().millisecondsSinceEpoch}',
              startDate: DateTime.now(),
              endDate: DateTime.now().add(const Duration(days: 1)),
            );
        String? formError;
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> pickDate(bool isStart) async {
              final picked = await showDatePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
                initialDate: isStart ? draft.startDate : draft.endDate,
              );
              if (picked == null) return;
              setModalState(() {
                draft = isStart
                    ? draft.copyWith(startDate: picked)
                    : draft.copyWith(endDate: picked);
              });
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 8,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    initial == null
                        ? 'Agregar cierre temporal'
                        : 'Editar cierre temporal',
                    style: AppTextStyles.headingMd,
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Fecha inicio'),
                    subtitle: Text(formatDateLong(draft.startDate)),
                    trailing: const Icon(Icons.event),
                    onTap: () => pickDate(true),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Fecha fin'),
                    subtitle: Text(formatDateLong(draft.endDate)),
                    trailing: const Icon(Icons.event),
                    onTap: () => pickDate(false),
                  ),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Motivo (opcional)',
                      hintText: 'Ej. vacaciones, refacción',
                    ),
                    controller: TextEditingController(text: draft.reason)
                      ..selection = TextSelection.collapsed(
                        offset: (draft.reason ?? '').length,
                      ),
                    onChanged: (value) => draft = draft.copyWith(reason: value),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Se verá como: Cerrado temporalmente (${formatDateRange(draft.startDate, draft.endDate)})',
                    style: AppTextStyles.bodySm
                        .copyWith(color: AppColors.secondary700),
                  ),
                  if (formError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      formError!,
                      style: AppTextStyles.bodySm
                          .copyWith(color: AppColors.errorFg),
                    ),
                  ],
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        final validation = validateTemporaryClosure(draft);
                        if (validation != null) {
                          setModalState(() => formError = validation);
                          return;
                        }
                        Navigator.of(context).pop(draft);
                      },
                      child: Text(
                        initial == null
                            ? 'Guardar cierre temporal'
                            : 'Guardar cambios',
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showHelp(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cómo cargar tus horarios'),
        content: const Text(
          'Elegí por día si está cerrado, horario corrido o horario cortado. '
          'Luego agregá excepciones de feriados o cierres temporales si lo necesitás.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleBackPress() async {
    final canLeave = await _onWillPop();
    if (!mounted || !canLeave) return;
    context.pop();
  }

  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges) return true;
    final discard = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Cambios sin guardar'),
            content:
                const Text('Tenés cambios sin guardar. ¿Querés salir igual?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Volver'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Salir sin guardar'),
              ),
            ],
          ),
        ) ??
        false;
    return discard;
  }

  static List<DayScheduleDraft> _defaultWeeklyClosed() {
    return orderedDayKeys
        .map(
          (day) => DayScheduleDraft(
            dayKey: day.key,
            dayLabel: day.label,
            mode: DayScheduleMode.closed,
          ),
        )
        .toList(growable: false);
  }

  static TimeOfDay? _timeOfDayFromHHmm(String? value) {
    if (value == null || !isValidTime(value)) return null;
    final parts = value.split(':');
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  static String _hhmmFromTimeOfDay(TimeOfDay value) {
    final h = value.hour.toString().padLeft(2, '0');
    final m = value.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
