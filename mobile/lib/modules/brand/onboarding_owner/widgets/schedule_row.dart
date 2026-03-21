import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';

class DaySchedule {
  final String day;
  bool enabled;
  TimeOfDay openTime;
  TimeOfDay closeTime;

  DaySchedule({
    required this.day,
    this.enabled = true,
    this.openTime = const TimeOfDay(hour: 9, minute: 0),
    this.closeTime = const TimeOfDay(hour: 20, minute: 0),
  });

  bool get hasTimeError =>
      enabled &&
      (closeTime.hour < openTime.hour ||
          (closeTime.hour == openTime.hour &&
              closeTime.minute <= openTime.minute));

  String get openLabel => _fmt(openTime);
  String get closeLabel => _fmt(closeTime);
  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

/// Fila de horario por día con toggle + time pickers.
/// EX-11: si closeTime < openTime → borde rojo en campo cierre + error inline.
class ScheduleRow extends StatelessWidget {
  final DaySchedule schedule;
  final ValueChanged<bool> onToggle;
  final ValueChanged<TimeOfDay> onOpenChanged;
  final ValueChanged<TimeOfDay> onCloseChanged;

  const ScheduleRow({
    super.key,
    required this.schedule,
    required this.onToggle,
    required this.onOpenChanged,
    required this.onCloseChanged,
  });

  Future<void> _pickTime(
    BuildContext context,
    TimeOfDay initial,
    ValueChanged<TimeOfDay> onChanged,
  ) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final hasError = schedule.hasTimeError;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Switch(
              value: schedule.enabled,
              onChanged: onToggle,
              activeColor: AppColors.primary500,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 36,
              child: Text(
                schedule.day,
                style: AppTextStyles.labelMd.copyWith(
                  color: schedule.enabled
                      ? AppColors.neutral900
                      : AppColors.neutral500,
                ),
              ),
            ),
            if (schedule.enabled) ...[
              const SizedBox(width: 8),
              _TimeButton(
                label: schedule.openLabel,
                hasError: false,
                onTap: () =>
                    _pickTime(context, schedule.openTime, onOpenChanged),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text('—',
                    style: AppTextStyles.bodySm
                        .copyWith(color: AppColors.neutral500)),
              ),
              // Campo cierre — borde rojo si EX-11
              _TimeButton(
                label: schedule.closeLabel,
                hasError: hasError,
                onTap: () =>
                    _pickTime(context, schedule.closeTime, onCloseChanged),
              ),
            ] else
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Text('Cerrado',
                    style: TextStyle(fontSize: 13, color: AppColors.neutral500)),
              ),
          ],
        ),
        // EX-11: error inline con valores reales
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(left: 56, top: 2, bottom: 4),
            child: Text(
              '△ El cierre (${schedule.closeLabel}) no puede ser antes de la apertura (${schedule.openLabel})',
              style: AppTextStyles.bodyXs.copyWith(color: AppColors.errorFg),
            ),
          ),
      ],
    );
  }
}

class _TimeButton extends StatelessWidget {
  final String label;
  final bool hasError;
  final VoidCallback onTap;

  const _TimeButton({
    required this.label,
    required this.hasError,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(
            color: hasError ? AppColors.errorFg : AppColors.neutral300,
            width: hasError ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelSm.copyWith(
            color: hasError ? AppColors.errorFg : AppColors.neutral900,
          ),
        ),
      ),
    );
  }
}
