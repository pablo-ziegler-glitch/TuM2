import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/schedule_model.dart';
import '../providers/store_providers.dart';

class ScheduleManagementScreen extends ConsumerStatefulWidget {
  final String storeId;

  const ScheduleManagementScreen({super.key, required this.storeId});

  @override
  ConsumerState<ScheduleManagementScreen> createState() =>
      _ScheduleManagementScreenState();
}

class _ScheduleManagementScreenState
    extends ConsumerState<ScheduleManagementScreen> {
  WeeklyScheduleModel? _editingSchedule;
  bool _isLoading = false;
  bool _initialized = false;

  Future<void> _save() async {
    if (_editingSchedule == null) return;
    setState(() => _isLoading = true);

    try {
      await ref.read(scheduleRepositoryProvider).saveSchedule(
            widget.storeId,
            _editingSchedule!,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Horario guardado')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No se pudo guardar el horario'),
          backgroundColor: TuM2Colors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheduleAsync =
        ref.watch(scheduleProvider(widget.storeId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Horarios'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _save,
            child: const Text('Guardar'),
          ),
        ],
      ),
      body: scheduleAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (schedule) {
          // Initialize with existing data or defaults
          if (!_initialized) {
            _editingSchedule = schedule ??
                WeeklyScheduleModel(
                  storeId: widget.storeId,
                  timezone: 'America/Argentina/Buenos_Aires',
                  monday: DaySchedule.defaultOpen,
                  tuesday: DaySchedule.defaultOpen,
                  wednesday: DaySchedule.defaultOpen,
                  thursday: DaySchedule.defaultOpen,
                  friday: DaySchedule.defaultOpen,
                  saturday: DaySchedule.defaultClosed,
                  sunday: DaySchedule.defaultClosed,
                  updatedAt: DateTime.now(),
                );
            _initialized = true;
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: 7,
            separatorBuilder: (_, __) =>
                const Divider(height: 1),
            itemBuilder: (ctx, index) => _DayRow(
              dayName: WeeklyScheduleModel.dayNames[index],
              daySchedule: _editingSchedule!.dayByIndex(index),
              onChanged: (updated) {
                setState(() {
                  _editingSchedule =
                      _editingSchedule!.copyWithDay(index, updated);
                });
              },
            ),
          );
        },
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  final String dayName;
  final DaySchedule daySchedule;
  final ValueChanged<DaySchedule> onChanged;

  const _DayRow({
    required this.dayName,
    required this.daySchedule,
    required this.onChanged,
  });

  Future<void> _pickTime(BuildContext context, bool isOpen) async {
    final currentTime = _parseTime(isOpen ? daySchedule.open : daySchedule.close);
    final picked = await showTimePicker(
      context: context,
      initialTime: currentTime,
    );
    if (picked == null) return;

    final formatted =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    if (isOpen) {
      onChanged(daySchedule.copyWith(open: formatted));
    } else {
      onChanged(daySchedule.copyWith(close: formatted));
    }
  }

  TimeOfDay _parseTime(String time) {
    final parts = time.split(':');
    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 9,
      minute: int.tryParse(parts[1]) ?? 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(dayName, style: TuM2TextStyles.bodyMedium),
          ),
          Switch(
            value: !daySchedule.closed,
            onChanged: (open) =>
                onChanged(daySchedule.copyWith(closed: !open)),
            activeColor: TuM2Colors.primary,
          ),
          if (!daySchedule.closed) ...[
            const Spacer(),
            GestureDetector(
              onTap: () => _pickTime(context, true),
              child: _TimeChip(time: daySchedule.open),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('—'),
            ),
            GestureDetector(
              onTap: () => _pickTime(context, false),
              child: _TimeChip(time: daySchedule.close),
            ),
          ] else
            Expanded(
              child: Text(
                'Cerrado',
                style: TuM2TextStyles.bodySmall
                    .copyWith(color: TuM2Colors.onSurfaceVariant),
                textAlign: TextAlign.end,
              ),
            ),
        ],
      ),
    );
  }
}

class _TimeChip extends StatelessWidget {
  final String time;

  const _TimeChip({required this.time});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: TuM2Colors.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(time, style: TuM2TextStyles.labelLarge),
    );
  }
}
