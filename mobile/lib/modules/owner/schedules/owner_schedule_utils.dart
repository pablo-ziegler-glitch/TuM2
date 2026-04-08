import 'package:intl/intl.dart';

import 'owner_schedule_models.dart';

final _hhmmRegex = RegExp(r'^(?:[01]\d|2[0-3]):[0-5]\d$');

bool isValidTime(String value) => _hhmmRegex.hasMatch(value);

int hhmmToMinutes(String value) {
  final parts = value.split(':');
  final hours = int.tryParse(parts.first) ?? 0;
  final minutes = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0;
  return (hours * 60) + minutes;
}

String? validateDaySchedule(DayScheduleDraft day) {
  if (day.mode == DayScheduleMode.closed) return null;

  if (day.mode == DayScheduleMode.continuous) {
    if (!_present(day.firstOpen) || !_present(day.firstClose)) {
      return 'Completá apertura y cierre.';
    }
    if (!isValidTime(day.firstOpen!) || !isValidTime(day.firstClose!)) {
      return 'Formato inválido. Usá HH:mm.';
    }
    if (hhmmToMinutes(day.firstOpen!) >= hhmmToMinutes(day.firstClose!)) {
      return 'La hora de cierre debe ser posterior a la apertura.';
    }
    return null;
  }

  if (!_present(day.firstOpen) ||
      !_present(day.firstClose) ||
      !_present(day.secondOpen) ||
      !_present(day.secondClose)) {
    return 'Completá ambas franjas del horario cortado.';
  }
  if (!isValidTime(day.firstOpen!) ||
      !isValidTime(day.firstClose!) ||
      !isValidTime(day.secondOpen!) ||
      !isValidTime(day.secondClose!)) {
    return 'Formato inválido. Usá HH:mm.';
  }

  final firstOpen = hhmmToMinutes(day.firstOpen!);
  final firstClose = hhmmToMinutes(day.firstClose!);
  final secondOpen = hhmmToMinutes(day.secondOpen!);
  final secondClose = hhmmToMinutes(day.secondClose!);
  if (firstOpen >= firstClose || secondOpen >= secondClose) {
    return 'Cada bloque debe tener apertura menor que cierre.';
  }
  if (firstClose >= secondOpen) {
    return 'Las franjas se superponen.';
  }
  return null;
}

String? validateException(ScheduleExceptionDraft exception) {
  if (exception.type == ScheduleExceptionType.closed) return null;
  return validateDaySchedule(
    DayScheduleDraft(
      dayKey: 'exception',
      dayLabel: 'Excepción',
      mode: exception.mode,
      firstOpen: exception.firstOpen,
      firstClose: exception.firstClose,
      secondOpen: exception.secondOpen,
      secondClose: exception.secondClose,
    ),
  );
}

String? validateTemporaryClosure(TemporaryClosureDraft closure) {
  if (closure.startDate.isAfter(closure.endDate)) {
    return 'La fecha de fin no puede ser menor a la de inicio.';
  }
  return null;
}

List<TimeBlock> dayBlocks(DayScheduleDraft day) {
  if (day.mode == DayScheduleMode.closed) return const [];
  if (day.mode == DayScheduleMode.continuous) {
    return [TimeBlock(open: day.firstOpen!, close: day.firstClose!)];
  }
  return [
    TimeBlock(open: day.firstOpen!, close: day.firstClose!),
    TimeBlock(open: day.secondOpen!, close: day.secondClose!),
  ];
}

List<TimeBlock> exceptionBlocks(ScheduleExceptionDraft exception) {
  if (exception.type == ScheduleExceptionType.closed) return const [];
  final draft = DayScheduleDraft(
    dayKey: 'exception',
    dayLabel: 'Excepción',
    mode: exception.mode,
    firstOpen: exception.firstOpen,
    firstClose: exception.firstClose,
    secondOpen: exception.secondOpen,
    secondClose: exception.secondClose,
  );
  return dayBlocks(draft);
}

String daySummary(DayScheduleDraft day) {
  if (day.mode == DayScheduleMode.closed) return 'Cerrado';
  if (day.mode == DayScheduleMode.continuous &&
      _present(day.firstOpen) &&
      _present(day.firstClose)) {
    return '${day.firstOpen} a ${day.firstClose}';
  }
  if (_present(day.firstOpen) &&
      _present(day.firstClose) &&
      _present(day.secondOpen) &&
      _present(day.secondClose)) {
    return '${day.firstOpen} a ${day.firstClose} y ${day.secondOpen} a ${day.secondClose}';
  }
  return 'Completar horario';
}

String exceptionSummary(ScheduleExceptionDraft exception) {
  if (exception.type == ScheduleExceptionType.closed) {
    return 'Cerrado todo el día';
  }
  final base = DayScheduleDraft(
    dayKey: 'exception',
    dayLabel: 'Excepción',
    mode: exception.mode,
    firstOpen: exception.firstOpen,
    firstClose: exception.firstClose,
    secondOpen: exception.secondOpen,
    secondClose: exception.secondClose,
  );
  return daySummary(base);
}

String modeLabel(DayScheduleMode mode) {
  switch (mode) {
    case DayScheduleMode.closed:
      return 'Cerrado';
    case DayScheduleMode.continuous:
      return 'Horario corrido';
    case DayScheduleMode.split:
      return 'Horario cortado';
  }
}

String formatDateLong(DateTime value) {
  return DateFormat("d 'de' MMMM", 'es_AR').format(value);
}

String formatDateRange(DateTime start, DateTime end) {
  final formatter = DateFormat("d 'de' MMM", 'es_AR');
  return '${formatter.format(start)} al ${formatter.format(end)}';
}

String buildTodayPreview({
  required DateTime now,
  required List<DayScheduleDraft> weekly,
  required List<ScheduleExceptionDraft> exceptions,
  required List<TemporaryClosureDraft> closures,
}) {
  final localDate = DateTime(now.year, now.month, now.day);
  final activeClosure = closures
      .where((closure) =>
          !localDate.isBefore(_dateOnly(closure.startDate)) &&
          !localDate.isAfter(_dateOnly(closure.endDate)))
      .toList()
    ..sort((a, b) => a.startDate.compareTo(b.startDate));
  if (activeClosure.isNotEmpty) {
    final closure = activeClosure.first;
    return 'Se verá como: Cerrado temporalmente (${formatDateRange(closure.startDate, closure.endDate)})';
  }

  final activeException = exceptions
      .where((exception) => _dateOnly(exception.date) == localDate)
      .toList();
  if (activeException.isNotEmpty) {
    final exception = activeException.first;
    if (exception.type == ScheduleExceptionType.closed) {
      return 'Se verá como: Horario especial por feriado (cerrado)';
    }
    return 'Se verá como: ${exceptionSummary(exception)}';
  }

  final dayKey = _weekdayToKey(localDate.weekday);
  final day = weekly.firstWhere(
    (element) => element.dayKey == dayKey,
    orElse: () => const DayScheduleDraft(
      dayKey: 'monday',
      dayLabel: 'Lunes',
      mode: DayScheduleMode.closed,
    ),
  );
  if (day.mode == DayScheduleMode.closed) return 'Se verá como: Cerrado hoy';
  return 'Se verá como: ${daySummary(day)}';
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

String _weekdayToKey(int weekday) {
  switch (weekday) {
    case DateTime.monday:
      return 'monday';
    case DateTime.tuesday:
      return 'tuesday';
    case DateTime.wednesday:
      return 'wednesday';
    case DateTime.thursday:
      return 'thursday';
    case DateTime.friday:
      return 'friday';
    case DateTime.saturday:
      return 'saturday';
    default:
      return 'sunday';
  }
}

bool _present(String? value) => value != null && value.trim().isNotEmpty;
